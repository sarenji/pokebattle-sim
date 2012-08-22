socket = require 'socket.io'

solid = require 'solid'

{BattleServer} = require './server'
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
            socket.emit 'adduser', prompt("What's your name?"), ->
              socket.on 'updatechat', (username, data) ->
                $("#messages").append("<p>#{username}: #{data}</p>")

              # Attach events to DOM
              $(document).on 'keyup', '#chat', (e) ->
                if e.which == 13
                  socket.emit 'sendchat', $(this).val()
                  $(this).val('')

              socket.on 'start battle', (battleId) ->
                $(document).on 'click', 'button', ->
                  socket.emit 'send move', battleId, $(this).text()
      @body ->
        @p '#messages'
        @input('#chat', type: 'text')
        @button 'Tackle'
        @button 'Splash'

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
