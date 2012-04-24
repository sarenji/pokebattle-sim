require 'js-yaml'
socket = require 'socket.io'

solid = require 'solid'

{Engine} = require './engine'
engine = new Engine
  moves: require './data/bw/moves.yml'

io = socket.listen solid (app) ->
  app.get '/jquery.js', @jquery
  app.get '/', @render ->
    @doctype 5
    @html ->
      @head ->
        @js '/jquery.js'
        @js '/socket.io/socket.io.js'
        @script @html_safe '''
          var socket = io.connect('http://localhost');
          socket.on('newuser', function (data) {
            console.log(data);
            $("#messages").append(data);
          });
        '''
      @body ->
        @p JSON.stringify(engine.moves)
        @p '#messages'

io.sockets.on 'connection', (socket) ->
  socket.emit 'newuser', 'you joined!'
