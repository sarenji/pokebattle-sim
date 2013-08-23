class @Pokemon extends Backbone.Model
  defaults:
    ivs:
      hp: 31
      attack: 31
      defense: 31
      specialAttack: 31
      specialDefense: 31
      speed: 31
    evs:
      hp: 0
      attack: 0
      defense: 0
      specialAttack: 0
      specialDefense: 0
      speed: 0

  initialize: (attributes) =>
    @species = PokemonData[attributes.name]

  getMovepool: ->
    # todo: cache this
    return _(@species.moves).map (moveName) ->
      move = MoveData[moveName]
      move['name'] = moveName
      move

  setIv: (stat, value) ->
    ivs = @get("ivs")
    ivs[stat] = value
    @set("ivs", ivs) # trigger change event

  setEv: (stat, value) ->
    evs = @get("evs")
    evs[stat] = value
    @set("evs", evs) # trigger change event

  iv: (stat) ->
    @get("ivs")[stat]

  ev: (stat) ->
    @get("evs")[stat]

  stat: (stat) ->
    return 500 # todo: calculate this