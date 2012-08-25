class @Battle extends Backbone.Model
  initialize: (attributes) =>
    {@socket, @you, @opponents} = attributes

  makeMove: (moveName) =>
    @socket.emit 'send move', @id, moveName

  makeSwitch: (toPokemon) =>
    @socket.emit 'send switch', @id, toPokemon

  switch: (fromIndex, toIndex) =>
    [@you[fromIndex], @you[toIndex]] = [@you[toIndex], @you[fromIndex]]

  emit: (args...) =>
    @socket(args...)
