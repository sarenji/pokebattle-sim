class @Pokemon extends Backbone.Model
  initialize: (attributes) =>
    @species = PokemonData[attributes.name]

  getMovepool: ->
    # todo: cache this
    return _(@species.moves).map (moveName) ->
      move = MoveData[moveName]
      move['name'] = moveName
      move 