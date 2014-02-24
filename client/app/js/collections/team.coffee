class @Team extends Backbone.Collection
  isTeambuilder: false

  initialize: (models, attributes = {}) =>
    {@name, @owner, @generation} = attributes
    @generation ?= DEFAULT_GENERATION
    @isTeambuilder = attributes.isTeambuilder

  getName: =>
    @name || "Untitled team"

  model: (attrs, options) =>
    if attrs.name
      attrs.teambuilder = @isTeambuilder
      return new Pokemon(attrs, options)
    else
      return new NullPokemon()

  toJSON: => {
      name: @name
      generation: @generation
      pokemon: super()
    }

  # Equivalent to toJSON, but omits NullPokemon
  toNonNullJSON: =>
    name: @name
    generation: @generation
    pokemon: _.chain(@models)
      .reject((pokemon) -> pokemon.isNull)
      .map((pokemon) -> pokemon.toJSON())
      .value()

  rearrange: (arrangement) ->
    @models = (@models[index]  for index in arrangement)
    return true

  getGeneration: (generation) ->
    gen = @generation || DEFAULT_GENERATION
    gen = gen.toUpperCase()
    window.Generations[gen]

  getPBV: =>
    gen = @getGeneration()
    pokemonList = _(@models).pluck("attributes")
    PokeBattle.PBV.determinePBV(gen, pokemonList)

  getNonNullPokemon: =>
    _(@models).where(isNull: false)

  hasNonNullPokemon: =>
    _(@models).some((model) -> not model.isNull)
