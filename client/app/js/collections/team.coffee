class @Team extends Backbone.Collection
  model: Pokemon

  initialize: (models, attributes = {}) =>
    {@owner} = attributes
