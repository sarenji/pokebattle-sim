class @Pokemon extends Backbone.Model
  defaults: =>
    name: 'Bulbasaur'
    moves: []
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

  getSpecies: ->
    FormeData[@get('name')].default

  getAbilities: ->
    species = @getSpecies()
    abilities = _.clone(species.abilities)
    abilities.push(species.hiddenAbility)
    abilities

  getMovepool: ->
    # todo: cache this
    species = @getSpecies()
    
    # only generations 3 to 5 for now

    learnset = []
    for generation in [3, 4, 5] 
      generationMoveMethods = species.learnset["generation-#{generation}"] || []
      for method, moves of generationMoveMethods
        learnset.push(moveName)  for moveName, level of moves

    learnset = _.chain(learnset).sort().unique(true).value()

    # Map each move name to a move object
    return _(learnset).map (moveName) ->
      move = _(MoveData[moveName]).clone()
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