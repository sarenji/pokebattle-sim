http = require 'http'
express = require 'express'
redis = require 'redis'
require 'sugar'

# Variables
process.env.NODE_ENV ||= "development"
PORT = process.env.PORT || 8000

config = require './server/config'
{BattleServer} = require './server/server'
{ConnectionServer} = require './server/connections'
authentication = require('./server/authentication')
ladders = require './shared/ladders'

server = new BattleServer()
app = express()
httpServer = http.createServer(app)

# Connect to redis
if process.env.REDIS_DB_URL
  parts = require("url").parse(process.env.REDIS_DB_URL)
  db = redis.createClient(parts.port, parts.hostname)
  db.auth(parts.auth.split(":")[1])  if parts.auth
else
  db = redis.createClient()

# Configuration
app.set("views", "client")
app.use(express.logger())
app.use(express.compress())  # gzip
app.use(express.bodyParser())
app.use(express.cookieParser())
app.use(authentication.middleware())
app.use(express.methodOverride())
app.use(app.router)
app.use(express.static(__dirname + "/public"))

# Routing
renderHomepage = (req, res) ->
  res.render 'index.jade', username: req.user.username

app.get("/", renderHomepage)
app.get("/battles/:id", renderHomepage)

userList = []

# Start responding to websocket clients
connections = new ConnectionServer(httpServer, prefix: '/socket')

connections.addEvents
  'login': (user, sessionId) ->
    authentication.auth sessionId, (body) ->
      if !body
        user.send('error', "Something went wrong connecting to the server.")
        return
      else
        user.id = body.username
        user.send 'list chatroom', userList.map((u) -> u.toJSON())
        userList.push(user)
        user.send 'login success', user.toJSON()
        connections.broadcast 'join chatroom', user.toJSON()

  'send chat': (user, message) ->
    return  unless user.isLoggedIn() && message?.replace(/\s+/, '').length > 0
    user.broadcast 'update chat', user.toJSON(), message

  'send battle chat': (user, battleId, message) ->
    return  unless user.isLoggedIn() && message?.replace(/\s+/, '').length > 0
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    battle.messageSpectators(user, message)

  'save team': (user, team) ->
    console.log(team) # todo: implement this

  'close': (user) ->
    userList.remove((u) -> u == user)
    user.broadcast 'leave chatroom', user.toJSON()
    # TODO: Remove from battles as well
    # TODO: Dequeue player from finding battles

  ###########
  # BATTLES #
  ###########

  'find battle': (user, team, generation) ->
    if generation not in ladders.SUPPORTED_GENERATIONS
      user.send("error", [ "Invalid generation: #{generation}" ])
      return

    errors = server.validateTeam(team, generation)
    if errors.length > 0
      user.send("error", errors)
      return

    server.queuePlayer(user, team, generation)

    # TODO: Pair players on an interval.
    if server.queuedPlayers(generation).length >= 2
      battles = server.beginBattles()
      for battle in battles
        [ first, second, id ] = battle
        message = """#{first.id} vs. #{second.id}!
        <span class="fake_link spectate" data-battle-id="#{id}">Watch</span>"""
        connections.broadcast('raw message', message)

  'send move': (user, battleId, moveName, slot, forTurn, args...) ->
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    battle.makeMove(user, moveName, slot, forTurn, args...)
  
  'send switch': (user, battleId, toSlot, fromSlot, forTurn) ->
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    battle.makeSwitch(user, toSlot, fromSlot, forTurn)

  'arrange team': (user, battleId, arrangement) ->
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    battle.arrangeTeam(user, arrangement)

  'spectate battle': (user, battleId) ->
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    battle.addSpectator(user)

  'leave battle': (user, battleId) ->
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    battle.removeSpectator(user)

  'forfeit': (user, battleId) ->
    battle = server.findBattle(battleId)
    if !battle
      user.send 'error', 'ERROR: Battle does not exist'
      return

    battle.forfeit(user)

  # TODO: socket.off after disconnection

httpServer.listen(PORT)
