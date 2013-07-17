class @Battle extends Backbone.Model
  initialize: (attributes) =>
    {@socket, @you, @opponents} = attributes

  makeMove: (moveName) =>
    @socket.send 'send move', @id, moveName

  makeSwitch: (toPokemon) =>
    @socket.send 'send switch', @id, toPokemon

  switch: (fromIndex, toIndex) =>
    [@you[fromIndex], @you[toIndex]] = [@you[toIndex], @you[fromIndex]]

  emit: (args...) =>
    @socket(args...)
