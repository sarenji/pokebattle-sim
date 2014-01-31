class @PrivateMessage extends Backbone.Model
  initialize: =>
    @clear()

  add: (username, message, opts = {}) =>
    log = @get('log')
    log.push({username, message, opts})
    @trigger("receive", @id, username, message, opts)

  clear: =>
    @set('log', [])
