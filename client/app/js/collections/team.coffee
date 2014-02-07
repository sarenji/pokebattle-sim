class @Team extends Backbone.Collection
  model: Pokemon

  initialize: (models, attributes = {}) =>
    {@name, @owner, @generation} = attributes
    @generation ?= DEFAULT_GENERATION

  getName: =>
    @name || "Untitled team"

  toJSON: => {
      name: @name
      generation: @generation
      pokemon: super()
    }

  getGeneration: (generation) ->
    gen = @generation || DEFAULT_GENERATION
    gen = gen.toUpperCase()
    window.Generations[gen]

  getPBV: =>
    gen = @getGeneration()
    pokemonList = _(@models).pluck("attributes")
    PokeBattle.PBV.determinePBV(gen, pokemonList)
