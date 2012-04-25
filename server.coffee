require 'js-yaml'
socket = require 'socket.io'

solid = require 'solid'

{Engine} = require './engine'
engine = new Engine
  moves: require('./data/bw/moves.yml').shift()
  pokemon: require('./data/bw/pokemon.yml').shift()

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
          socket.on 'newuser', (data) ->
            console.log(data)
            $("#messages").append(data)
      @body ->
        @p JSON.stringify(engine.moves)
        @p JSON.stringify(engine.pokemon)
        @p '#messages'
        @button 'Tackle'

io.sockets.on 'connection', (socket) ->
  socket.emit 'newuser', 'you joined!'
