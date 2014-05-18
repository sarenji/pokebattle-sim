http = require 'http'
express = require 'express'
path = require 'path'
{_} = require 'underscore'

{BattleServer} = require './server'
{ConnectionServer} = require './connections'
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
  httpServer.battleServer = server = new BattleServer()

  # Configuration
  app.set("views", "client")
  app.use(express.logger())
  app.use(express.compress())  # gzip
  app.use(express.bodyParser())
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
  connections = new ConnectionServer(httpServer, lobby, prefix: '/socket')

  connections.addEvents
    'connection': (user) ->
      user.send('version', CLIENT_VERSION)

    'login': (user, id, token) ->
      auth.matchToken id, token, (err, json) ->
        if err then return user.error(errors.INVALID_SESSION)

        # REFACTOR INCOMING: The simulator currently uses user.id as the username of the user,
        # there is no such as a numeric id. Eventually, we want to switch to a separated id/name system
        # user.id will still be the same thing in the meantime, but now user._id and user.name will exist too.
        # Eventually, once all uses of .id in the server are changed to ._id, replace all ._id -> .id
        user.id = json.username   # will become deprecated
        user._id = json.id        # user id
        user.name = json.username # username

        auth.getBanTTL user.id, (err, ttl) ->
          if err
            return user.error(errors.INVALID_SESSION)
          else if ttl != -2  # -2 means the ban does not exist
            auth.getBanReason user.id, (err, reason) ->
              user.error(errors.BANNED, reason, Number(ttl))
              user.close()
              return
          else
            server.setAuthority(user, json.authority)
            user.send('loginSuccess')
            numConnections = lobby.addUser(user)
            connections.broadcast('joinChatroom', user.toJSON())  if numConnections == 1
            user.send('listChatroom', lobby.userJSON())
            server.join(user)

            alts.listUserAlts user.id, (err, alts) ->
              user.send('altList', alts)

    'sendChat': (user, message) ->
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

    'sendBattleChat': (user, battleId, message) ->
      return  if typeof message != "string"
      return  if message.trim().length == 0
      return  if message.length > MAX_MESSAGE_LENGTH
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.messageSpectators(user, message)

    'close': (user) ->
      # Do nothing if this user never logged in.
      return  if !user.id?
      server.leave(user)
      if lobby.removeUser(user) == 0  # No more connections.
        user.broadcast('leaveChatroom', user.id)
        connections.trigger(user, "cancelFindBattle")

    #########
    # TEAMS #
    #########

    # Takes a temporary id and team JSON. Saves to server, and returns the real
    # unique id that was persisted onto the DB.
    'saveTeam': (user, team, cid) ->
      attributes = _.pick(team, 'id', 'name', 'generation')
      attributes['trainer_id'] = user._id
      attributes['contents'] = JSON.stringify(team.pokemon)
      new database.Team(attributes)
        .save().then (team) ->
          user.send('teamSaved', cid, team.id)

    'requestTeams': (user) ->
      q = new database.Teams()
      q = q.query('where', trainer_id: user._id)  unless config.IS_LOCAL
      q = q.query('orderBy', 'created_at')
        .fetch()
        .then (teams) ->
          user.send('receiveTeams', teams.toJSON())

    'destroyTeam': (user, teamId) ->
      new database.Team(trainer_id: user._id, id: teamId)
        .fetch(columns: ['id'])
        .then (team) ->
          team?.destroy()

    ####################
    # PRIVATE MESSAGES #
    ####################

    'privateMessage': (user, toUser, message) ->
      return  unless typeof message == "string" && message.trim().length > 0
      if server.users.contains(toUser)
        server.users.send(toUser, 'privateMessage', user.id, message)
      else
        user.error(errors.PRIVATE_MESSAGE, toUser, "This user is offline.")

    ##############
    # CHALLENGES #
    ##############

    'challenge': (user, challengeeId, generation, team, conditions, altName) ->
      alts.isAltOwnedBy user.id, altName, (err, valid) ->
        return user.error(errors.INVALID_ALT_NAME, "You do not own this alt")  unless valid
        server.registerChallenge(user, challengeeId, generation, team, conditions, altName)

    'cancelChallenge': (user, challengeeId) ->
      server.cancelChallenge(user, challengeeId)

    'acceptChallenge': (user, challengerId, team, altName) ->
      alts.isAltOwnedBy user.id, altName, (err, valid) ->
        return user.error(errors.INVALID_ALT_NAME, "You do not own this alt")  unless valid
        server.acceptChallenge(user, challengerId, team, altName)

    'rejectChallenge': (user, challengerId, team) ->
      server.rejectChallenge(user, challengerId)

    ##############
    # ALTS #
    ##############

    'createAlt': (user, altName) ->
      altName = String(altName).trim()
      if !alts.isAltNameValid(altName)
        return user.error(errors.INVALID_ALT_NAME, "Invalid Alt Name")
      alts.createAlt user.id, altName, (err, success) ->
        return user.error(errors.INVALID_ALT_NAME, err.message)  if err
        user.send('altCreated', altName)  if success

    ###########
    # BATTLES #
    ###########

    'getBattleList': (user) ->
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
      user.send('battleList', battleMetadata)

    'findBattle': (user, generation, team, altName=null) ->
      if generation not in generations.SUPPORTED_GENERATIONS
        user.error(errors.FIND_BATTLE, [ "Invalid generation: #{generation}" ])
        return

      # Note: If altName == null, then isAltOwnedBy will return true
      alts.isAltOwnedBy user.id, altName, (err, valid) ->
        if not valid
          user.error(errors.INVALID_ALT_NAME, "You do not own this alt")
        else
          validationErrors = server.queuePlayer(user.id, team, generation, altName)
          if validationErrors.length > 0
            user.error(errors.FIND_BATTLE, validationErrors)

    'cancelFindBattle': (user, generation) ->
      server.removePlayer(user.id, generation)
      user.send("findBattleCanceled")

    'sendMove': (user, battleId, moveName, slot, forTurn, args...) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.makeMove(user.id, moveName, slot, forTurn, args...)
    
    'sendSwitch': (user, battleId, toSlot, fromSlot, forTurn) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.makeSwitch(user.id, toSlot, fromSlot, forTurn)

    'sendCancelAction': (user, battleId, forTurn) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.undoCompletedRequest(user.id, forTurn)

    'arrangeTeam': (user, battleId, arrangement) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.arrangeTeam(user.id, arrangement)

    'spectateBattle': (user, battleId) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.addSpectator(user)

    'leaveBattle': (user, battleId) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.removeSpectator(user)

    'forfeit': (user, battleId) ->
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.forfeit(user.id)

    # TODO: socket.off after disconnection

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

  httpServer
