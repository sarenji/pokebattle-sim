http = require 'http'
express = require 'express'
path = require 'path'
require 'sugar'

{BattleServer} = require './server'
{ConnectionServer} = require './connections'
commands = require './commands'
auth = require('./auth')
generations = require './generations'
{Room} = require('./rooms')
errors = require '../shared/errors'

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
  app.use(express.static(path.join(__dirname, "../public")))

  # Routing
  renderHomepage = (req, res) ->
    res.render 'index.jade', user: req.user

  app.get("/", renderHomepage)
  app.get("/battles/:id", renderHomepage)

  lobby = new Room("Lobby")
  server.rooms.push(lobby)

  # Start responding to websocket clients
  connections = new ConnectionServer(httpServer, lobby, prefix: '/socket')

  connections.addEvents
    'login': (user, id, token) ->
      auth.matchToken id, token, (err, json) ->
        if err then return user.error(errors.INVALID_SESSION)
        user.id = json.username
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

    'sendChat': (user, message) ->
      return  unless typeof message == "string" && message.trim().length > 0
      server.limit user, 'chat', max: 10, duration: 3000, (err, limit) ->
        if !limit.remaining
          auth.getMuteTTL user.id, (err, ttl) ->
            if ttl == -2
              server.mute(user.id, "[AUTOMATED] Triggered chat rate-limit.", 3 * 60)
              lobby.message("#{user.id} was muted because they were spamming.")
            else
              user.message("You are muted for another #{ttl} seconds!")
        else if message[0] == '/'
          [ command, args... ] = message.split(/\s+/)
          command = command.substr(1)
          args = args.join(' ').split(/,/g)
          commands.executeCommand(server, user, lobby, command, args...)
        else
          server.userMessage(lobby, user, message)

    'sendBattleChat': (user, battleId, message) ->
      return  unless message?.replace(/\s+/, '').length > 0
      battle = server.findBattle(battleId)
      if !battle
        user.error(errors.BATTLE_DNE)
        return

      battle.messageSpectators(user, message)

    'saveTeam': (user, team) ->
      console.log(team) # todo: implement this

    'close': (user) ->
      # Do nothing if this user never logged in.
      return  if !user.id?
      server.leave(user)
      if lobby.removeUser(user) == 0  # No more connections.
        user.broadcast('leaveChatroom', user.id)
        connections.trigger(user, "cancelFindBattle")


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

    'challenge': (user, challengeeId, generation, team, conditions) ->
      server.registerChallenge(user, challengeeId, generation, team, conditions)

    'cancelChallenge': (user, challengeeId) ->
      server.cancelChallenge(user, challengeeId)

    'acceptChallenge': (user, challengerId, team) ->
      battleId = server.acceptChallenge(user, challengerId, team)
      if battleId
        lobby.message("""Challenge: <span class="fake_link spectate"
        data-battle-id="#{battleId}">#{challengerId} vs. #{user.id}</span>!""")

    'rejectChallenge': (user, challengerId, team) ->
      server.rejectChallenge(user, challengerId)

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
          controller.battle.playerIds[0],
          controller.battle.playerIds[1],
          currentTime - controller.battle.createdAt
        ] for controller in server.getOngoingBattles())
      user.send('battleList', battleMetadata)

    'findBattle': (user, generation, team) ->
      if generation not in generations.SUPPORTED_GENERATIONS
        user.error(errors.FIND_BATTLE, [ "Invalid generation: #{generation}" ])
        return

      validationErrors = server.queuePlayer(user.id, team, generation)
      if validationErrors.length > 0
        user.error(errors.FIND_BATTLE, validationErrors)
        return

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
        playerNames = battle.getPlayerIds()
        message = """Ladder match: <span class="fake_link spectate"
        data-battle-id="#{id}">#{playerNames.join(" vs. ")}</span>!"""
        lobby.message(message)
    setTimeout(battleSearch, 5 * 1000)

  battleSearch()

  httpServer.listen(port)

  httpServer
