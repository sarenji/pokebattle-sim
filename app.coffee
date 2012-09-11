http = require 'http'
socket = require 'socket.io'
express = require 'express'
require 'express-namespace'

{BattleServer} = require './server'

server = new BattleServer()
app = express()
httpServer = http.createServer(app)

# Configuration
app.use(express.bodyParser())
app.use(express.methodOverride())
app.use(app.router)
app.use(require('connect-assets')())

# Routing
app.get '/', (req, res) ->
  res.render 'index.jade'

# API
app.namespace "/v1/api", ->
  app.get '/pokemon', (req, res) ->
    {PokemonData} = require './data/bw'
    res.json(PokemonData)


# Start responding to websocket clients
io = socket.listen(httpServer)

userList = []

# Attach events to incoming users
io.sockets.on 'connection', (socket) ->
  socket.on 'login', (username, callback) ->
    userHash = {id: socket.id, name: username}
    userList.push(userHash)
    socket.username = username
    callback(socket.username, userList)
    io.sockets.emit 'join chatroom', userHash
    # TODO: Take team from player.
    # TODO: Validate team.
    team = defaultTeam
    server.queuePlayer(socket, team)
    if server.queuedPlayers().length == 2
      server.beginBattles()
  socket.on 'sendchat', (message) ->
    io.sockets.emit 'updatechat', socket.username, message
  socket.on 'send move', (battleId, moveName) ->
    server.findBattle(battleId).makeMove(socket, moveName)
  socket.on 'send switch', (battleId, toPokemon) ->
    # TODO: Use makeSwitch instead
    server.findBattle(battleId).makeSwitchByName(socket, toPokemon)
  # TODO: socket.off after disconnection
  # Dequeue player in socket off

httpServer.listen(process.env.PORT || 8000)


# TODO: Implement team builder!
defaultTeam = [
  {
    name: "Pikachu"
    moves: ["Substitute", "Thunderbolt", "Hidden Power", "Grass Knot"]
    item: "Light Ball"
  }
  {
    name: "Hitmonchan"
    moves: ["Close Combat", "Mach Punch", "Ice Punch", "ThunderPunch"]
    item: "Life Orb"
  }
  {
    name: "Charizard"
    item: "Choice Specs"
    moves: ["Fire Blast", "Air Slash", "Hidden Power", "Focus Blast"]
  }
  {
    name: "Dragonite"
    item: "Leftovers"
    moves: ["Dragon Dance", "Outrage", "Fire Punch", "ExtremeSpeed"]
  }
  {
    name: "Jigglypuff"
    item: "Leftovers"
    moves: ["Sing", "Seismic Toss", "Protect", "Wish"]
  }
  {
    name: "Haunter"
    item: "Leftovers"
    moves: ["Substitute", "Disable", "Shadow Ball", "Focus Blast"]
  }
]
