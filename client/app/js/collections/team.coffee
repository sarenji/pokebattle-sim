class @Team extends Backbone.Collection
  model: Pokemon
  defaultGeneration: 'xy'

  initialize: (models, attributes = {}) =>
    {@name, @owner, @generation} = attributes
    @generation ?= @defaultGeneration

  getName: =>
    @name || "Untitled team"

  toJSON: => {
      name: @name
      generation: @generation
      pokemon: super()
    }
