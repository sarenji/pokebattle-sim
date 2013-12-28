http = require 'http'
express = require 'express'
require 'sugar'

# Variables
process.env.NODE_ENV ||= "development"
PORT = process.env.PORT || 8000

config = require './server/config'
{BattleServer} = require './server/server'
{ConnectionServer} = require './server/connections'
commands = require './server/commands'
auth = require('./server/auth')
ladders = require './shared/ladders'
{Room} = require('./server/rooms')
errors = require './shared/errors'

server = new BattleServer()
app = express()
httpServer = http.createServer(app)

# Configuration
app.set("views", "client")
app.use(express.logger())
app.use(express.compress())  # gzip
app.use(express.bodyParser())
app.use(express.cookieParser())
app.use(auth.middleware())
app.use(express.methodOverride())
app.use(app.router)
app.use(express.static(__dirname + "/public"))

# Routing
renderHomepage = (req, res) ->
  res.render 'index.jade', user: req.user

app.get("/", renderHomepage)
app.get("/battles/:id", renderHomepage)

lobby = new Room("Lobby")

# Start responding to websocket clients
connections = new ConnectionServer(httpServer, prefix: '/socket')

connections.addEvents
  'login': (user, id, token) ->
    auth.matchToken id, token, (err, json) ->
      if err then return user.error(errors.INVALID_SESSION)
      user.id = json.username
      user.setAuthority(json.authority)
      user.send('login success')
      numConnections = lobby.addUser(user)
      connections.broadcast('join chatroom', user.toJSON())  if numConnections == 1
      user.send('list chatroom', lobby.userJSON())

  'send chat': (user, message) ->
    return  unless typeof message == "string" && message.trim().length > 0
    if message[0] == '/'
      [ command, args... ] = message.split(/\s+/)
      command = command.substr(1)
      args = args.join(' ').split(/,\s*/g)
      commands.executeCommand(user, lobby, command, args...)
    else
      lobby.userMessage(user, message)

  'send battle chat': (user, battleId, message) ->
    return  unless message?.replace(/\s+/, '').length > 0
    battle = server.findBattle(battleId)
    if !battle
      user.error(errors.BATTLE_DNE)
      return

    battle.messageSpectators(user, message)

  'save team': (user, team) ->
    console.log(team) # todo: implement this

  'close': (user) ->
    if lobby.removeUser(user) == 0  # No more connections.
      user.broadcast('leave chatroom', user.id)
    # TODO: Remove from battles as well
    connections.trigger(user, "cancel find battle")

  ###########
  # BATTLES #
  ###########

  'find battle': (user, team, generation) ->
    if generation not in ladders.SUPPORTED_GENERATIONS
      user.error(errors.FIND_BATTLE, [ "Invalid generation: #{generation}" ])
      return

    validationErrors = server.validateTeam(team, generation)
    if validationErrors.length > 0
      user.error(errors.FIND_BATTLE, validationErrors)
      return

    server.queuePlayer(user, team, generation)

  'cancel find battle': (user, generation) ->
    server.removePlayer(user, generation)
    user.send("find battle canceled")

  'send move': (user, battleId, moveName, slot, forTurn, args...) ->
    battle = server.findBattle(battleId)
    if !battle
      user.error(errors.BATTLE_DNE)
      return

    battle.makeMove(user, moveName, slot, forTurn, args...)
  
  'send switch': (user, battleId, toSlot, fromSlot, forTurn) ->
    battle = server.findBattle(battleId)
    if !battle
      user.error(errors.BATTLE_DNE)
      return

    battle.makeSwitch(user, toSlot, fromSlot, forTurn)

  'arrange team': (user, battleId, arrangement) ->
    battle = server.findBattle(battleId)
    if !battle
      user.error(errors.BATTLE_DNE)
      return

    battle.arrangeTeam(user, arrangement)

  'spectate battle': (user, battleId) ->
    battle = server.findBattle(battleId)
    if !battle
      user.error(errors.BATTLE_DNE)
      return

    battle.addSpectator(user)

  'leave battle': (user, battleId) ->
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

    battle.forfeit(user)

  # TODO: socket.off after disconnection

battleSearch = ->
  server.beginBattles (err, battleIds) ->
    if err then return
    for id in battleIds
      message = """A new battle started!
      <span class="fake_link spectate" data-battle-id="#{id}">Watch</span>"""
      lobby.message(message)
  setTimeout(battleSearch, 5 * 1000)

battleSearch()

httpServer.listen(PORT)
