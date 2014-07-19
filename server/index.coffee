http = require 'http'
Primus = require 'primus'
Emitter = require('primus-emitter')
express = require 'express'
path = require 'path'
{_} = require 'underscore'

{BattleServer} = require './server'
commands = require './commands'
auth = require('./auth')
generations = require './generations'
{Room} = require('./rooms')
errors = require '../shared/errors'
assets = require('../assets')
database = require('./database')
redis = require('./redis')
ratings = require('./ratings')
config = require('./config')
alts = require('./alts')
replays = require('./replays')

MAX_MESSAGE_LENGTH = 250
MAX_RANK_DISPLAYED = 100

# A MD5 hash of all the JavaScript files used by the client. This is passed to
# each new connection via the .jade template, and when the client connects. If
# the two versions differ, the server had restarted at some point and now is
# serving new client files.
CLIENT_VERSION = assets.getVersion()

@createServer = (port) ->
  app = express()
  httpServer = http.createServer(app)
  primus = new Primus(httpServer, transformer: 'sockjs')
  primus.use('emitter', Emitter)
  primus.save(path.join(__dirname, "../client/vendor/js/primus.js"))
  server = new BattleServer()

  # Configuration
  app.set("views", "client/templates")
  app.set('view engine', 'jade')
  app.use(express.logger())  if config.IS_LOCAL
  app.use(express.compress())  # gzip
  app.use(express.cookieParser())
  app.use(auth.middleware())
  app.use(express.methodOverride())
  app.use(app.router)
  app.use(express.static(path.join(__dirname, "../public")))  if config.IS_LOCAL

  # Helpers
  app.locals.asset_path = assets.getAbsolute

  # Routing
  renderHomepage = (req, res) ->
    res.render('index.jade', user: req.user, CLIENT_VERSION: CLIENT_VERSION)

  app.get("/", renderHomepage)
  app.get("/battles/:id", renderHomepage)
  app.get("/replays/:id", replays.routes.show)
  app.delete("/replays/:id", replays.routes.destroy)
  app.get("/replays", replays.routes.index)

  app.get '/leaderboard', (req, res) ->
    page = req.param('page')
    perPage = req.param('per_page')
    ratings.listRatings page, perPage, (err, results) ->
      if err
        res.json(500, err.message)
      else
        res.json(players: results)

  lobby = new Room("Lobby")
  server.rooms.push(lobby)

  # Start responding to websocket clients
  primus.on 'connection', (spark) ->
    spark.send('version', CLIENT_VERSION)

    spark.on 'login', (id, token) ->
      auth.matchToken id, token, (err, json) ->
        if err then return spark.send('errorMessage', errors.INVALID_SESSION)

        auth.getBanTTL json.name, (err, ttl) ->
          if err
            return spark.send('errorMessage', errors.INVALID_SESSION)
          else if ttl != -2  # -2 means the ban does not exist
            auth.getBanReason json.name, (err, reason) ->
              spark.send('errorMessage', errors.BANNED, reason, Number(ttl))
              spark.end()
              return
          else
            user = server.findOrCreateUser(json, spark)
            server.join(spark)
            spark.send('loginSuccess')
            lobby.add(spark)

            # After stuff
            attachEvents(user, spark)
            alts.listUserAlts user.name, (err, alts) ->
              spark.send('altList', alts)

  primus.on 'error', (err) ->
    console.error(err.message, err.stack)

  attachEvents = (user, spark) ->
    spark.on 'sendChat', (message) ->
      return  if typeof message != "string"
      return  if message.trim().length == 0
      return  if message.length > MAX_MESSAGE_LENGTH
      if message[0] == '/' && message[1] == '/'
        message = message[1...]
        server.userMessage(lobby, user, message)
      else if message[0] == '/'
        command = message.replace(/\s+.*$/, '')
        args = message.substr(command.length).replace(/^\s+/, '')
        command = command.substr(1)
        args = args.split(',')
        commands.executeCommand(server, user, lobby, command, args...)
      else
        server.userMessage(lobby, user, message)

    spark.on 'sendBattleChat', (battleId, message) ->
      return  if typeof message != "string"
      return  if message.trim().length == 0
      return  if message.length > MAX_MESSAGE_LENGTH
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      # TODO: Use `userMessage` instead once rooms are implemented
      auth.getMuteTTL user.name, (err, ttl) ->
        if ttl == -2
          battle.messageSpectators(user, message)
        else
          user.announce('warning', "You are muted for another #{ttl} seconds!")

    # After the `end` event, each listener should automatically disconnect.
    spark.on 'end', ->
      server.leave(spark)
      spark.emit("cancelFindBattle")  unless spark.user.hasSparks()

    #########
    # TEAMS #
    #########

    # Takes a temporary id and team JSON. Saves to server, and returns the real
    # unique id that was persisted onto the DB.
    spark.on 'saveTeam', (team, callback) ->
      attributes = _.pick(team, 'id', 'name', 'generation')
      attributes['trainer_id'] = user.id
      attributes['contents'] = JSON.stringify(team.pokemon)
      new database.Team(attributes)
        .save().then (team) ->
          callback?(team.id)

    spark.on 'requestTeams', ->
      q = new database.Teams()
      q = q.query('where', trainer_id: user.id)  unless config.IS_LOCAL
      q = q.query('orderBy', 'created_at')
        .fetch()
        .then (teams) ->
          user.send('receiveTeams', teams.toJSON())

    spark.on 'destroyTeam', (teamId) ->
      attributes = {
        id: teamId
      }
      attributes['trainer_id'] = user.id  unless config.IS_LOCAL
      new database.Team(attributes)
        .fetch(columns: ['id'])
        .then (team) ->
          # If there is no team, the user doesn't own it.
          team?.destroy()

    ####################
    # PRIVATE MESSAGES #
    ####################

    spark.on 'privateMessage', (toUser, message) ->
      return  unless typeof message == "string" && message.trim().length > 0
      if server.users.contains(toUser)
        recipient = server.users.get(toUser)
        recipient.send('privateMessage', user.name, user.name, message)
        user.send('privateMessage', toUser, user.name, message)
      else
        user.error(errors.PRIVATE_MESSAGE, toUser, "This user is offline.")

    ##############
    # CHALLENGES #
    ##############

    spark.on 'challenge', (challengeeId, generation, team, conditions, altName) ->
      alts.isAltOwnedBy user.name, altName, (err, valid) ->
        return user.error(errors.INVALID_ALT_NAME, "You do not own this alt")  unless valid
        server.registerChallenge(user, challengeeId, generation, team, conditions, altName)

    spark.on 'cancelChallenge', (challengeeId) ->
      server.cancelChallenge(user, challengeeId)

    spark.on 'acceptChallenge', (challengerId, team, altName) ->
      alts.isAltOwnedBy user.name, altName, (err, valid) ->
        return user.error(errors.INVALID_ALT_NAME, "You do not own this alt")  unless valid
        server.acceptChallenge(user, challengerId, team, altName)

    spark.on 'rejectChallenge', (challengerId, team) ->
      server.rejectChallenge(user, challengerId)

    ########
    # ALTS #
    ########

    spark.on 'createAlt', (altName) ->
      altName = String(altName).trim()
      if !alts.isAltNameValid(altName)
        return user.error(errors.INVALID_ALT_NAME, "Invalid Alt Name")
      alts.createAlt user.name, altName, (err, success) ->
        return user.error(errors.INVALID_ALT_NAME, err.message)  if err
        user.send('altCreated', altName)  if success

    ###########
    # REPLAYS #
    ###########

    spark.on 'saveReplay', (battleId, callback) ->
      battle = server.findBattle(battleId)
      return callback?("The battle could not be found.")  unless battle
      return callback?("The battle is not yet done.")  unless battle.isOver()
      replays.create(user, battle.battle)  # unwrap the facade
        .then((replayId) -> callback?(null, replayId))
        .catch replays.TooManyBattlesSaved, (err) ->
          callback?(err.message)
        .catch (err) ->
          callback?('Something went wrong saving the replay.')

    ###########
    # BATTLES #
    ###########

    spark.on 'getBattleList', (callback) ->
      # TODO: Make this more efficient
      # TODO: Order by age
      # NOTE: Cache this? Even something like a 5 second expiration
      # may improve server performance greatly
      currentTime = Date.now()
      battleMetadata = ([
          controller.battle.id,
          controller.battle.playerNames[0],
          controller.battle.playerNames[1],
          currentTime - controller.battle.createdAt
        ] for controller in server.getOngoingBattles())
      callback?(battleMetadata)

    spark.on 'findBattle', (format, team, altName=null) ->
      # Note: If altName == null, then isAltOwnedBy will return true
      alts.isAltOwnedBy user.name, altName, (err, valid) ->
        if not valid
          user.error(errors.INVALID_ALT_NAME, "You do not own this alt")
        else
          validationErrors = server.queuePlayer(user.name, team, format, altName)
          if validationErrors.length > 0
            user.error(errors.FIND_BATTLE, validationErrors)

    spark.on 'cancelFindBattle', (generation) ->
      server.removePlayer(user.name, generation)
      user.send("findBattleCanceled")

    spark.on 'sendMove', (battleId, moveName, slot, forTurn, options, callback) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.makeMove(user.name, moveName, slot, forTurn, options)
      callback?()
    
    spark.on 'sendSwitch', (battleId, toSlot, fromSlot, forTurn, callback) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.makeSwitch(user.name, toSlot, fromSlot, forTurn)
      callback?()

    spark.on 'sendCancelAction', (battleId, forTurn) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.undoCompletedRequest(user.name, forTurn)

    spark.on 'arrangeTeam', (battleId, arrangement) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.arrangeTeam(user.name, arrangement)

    spark.on 'spectateBattle', (battleId) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.addSpectator(spark)

    spark.on 'leaveBattle', (battleId) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.removeSpectator(spark)

    spark.on 'forfeit', (battleId) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.forfeit(user.name)

  battleSearch = ->
    server.beginBattles (err, battleIds) ->
      if err then return
      for id in battleIds
        battle = server.findBattle(id)
        playerIds = battle.getPlayerIds()
        ratingKeys = playerIds.map((id) -> battle.getPlayer(id).ratingKey)
        ratings.getRanks ratingKeys, (err, fullRanks) ->
          ranks = _.compact(fullRanks)
          return  unless ranks.length == fullRanks.length
          if 1 <= Math.max(ranks...) <= MAX_RANK_DISPLAYED
            playerNames = battle.getPlayerNames()
            playerNames = playerNames.map((p, i) -> "#{p} (Rank ##{ranks[i]})")
            message = """A high-level match is being played!
            <span class="fake_link spectate" data-battle-id="#{id}">
              #{playerNames.join(" vs. ")}</span>!"""
            lobby.message(message)
    setTimeout(battleSearch, 5 * 1000)

  battleSearch()

  httpServer.listen(port)

  primus
