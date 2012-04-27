require 'js-yaml'
socket = require 'socket.io'

solid = require 'solid'

{BattleServer} = require './server'
{Engine} = require './engine'
engine = new Engine
  moves: require('./data/bw/moves.yml').shift()
  pokemon: require('./data/bw/pokemon.yml').shift()

server = new BattleServer()

# Start responding to clients
io = socket.listen solid (app) ->
  app.get '/jquery.js', @jquery
  app.get '/', @render ->
    @doctype 5
    @html ->
      @head ->
        @js '/jquery.js'
        @js '/socket.io/socket.io.js'
        @script ->
          socket = io.connect('http://localhost')
          socket.on 'connect', ->
            socket.emit 'adduser', prompt("What's your name?")
            socket.on 'updatechat', (username, data) ->
              $("#messages").append("<p>#{username}: #{data}</p>")
          $(document).on 'keyup', '#chat', (e) ->
            if e.which == 13
              socket.emit 'sendchat', $(this).val()
              $(this).val('')
      @body ->
        @p JSON.stringify(engine.moves)
        @p JSON.stringify(engine.pokemon)
        @p '#messages'
        @input('#chat', type: 'text')
        @button 'Tackle'

# Attach events to incoming users
io.sockets.on 'connection', (socket) ->
  socket.on 'adduser', (username) ->
    socket.username = username
    server.queue.queuePlayer(socket)
    server.queue.pairPlayers()
    socket.broadcast.emit 'updatechat', 'SERVER', "#{username} joined the game!"
  socket.on 'sendchat', (message) ->
    io.sockets.emit 'updatechat', socket.username, message
  # TODO: socket.off after disconnection
