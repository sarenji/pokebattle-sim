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

# Attach events to incoming users
io.sockets.on 'connection', (socket) ->
  socket.on 'adduser', (username, callback) ->
    socket.username = username
    callback(socket.username)
    # TODO: Take team from player.
    # TODO: Validate team.
    team = [{name: 'Magikarp', moves: ['tackle', 'splash']}]
    server.queuePlayer(socket, team)
    if server.queuedPlayers().length == 2
      server.beginBattles()
    io.sockets.emit 'updatechat', 'SERVER', "#{username} joined the game!"
  socket.on 'sendchat', (message) ->
    io.sockets.emit 'updatechat', socket.username, message
  socket.on 'send move', (battleId, moveName) ->
    server.findBattle(battleId).makeMove(socket, moveName)
  # TODO: socket.off after disconnection
  # Dequeue player in socket off

httpServer.listen(process.env.PORT || 8000)
