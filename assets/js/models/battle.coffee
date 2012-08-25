class @Battle extends Backbone.Model
  initialize: (attributes) =>
    {@socket, @you, @opponents} = attributes

  makeMove: (moveName) =>
    @socket.emit 'send move', @id, moveName

  makeSwitch: (toPokemon) =>
    @socket.emit 'send switch', @id, toPokemon

  emit: (args...) =>
    @socket(args...)
