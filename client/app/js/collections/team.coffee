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
