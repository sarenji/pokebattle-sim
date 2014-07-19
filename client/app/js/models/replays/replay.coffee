class @Replay extends Backbone.Model
  urlRoot: '/replays'

  getFormat: ->
    window.Formats[@get('format')].humanName
