class @Team extends Backbone.Collection
  model: Pokemon

  initialize: (models, attributes = {}) =>
    {@name, @owner} = attributes

  getName: =>
    @name || "Untitled team"

  toJSON: => {
      name: @name
      pokemon: super()
    }
