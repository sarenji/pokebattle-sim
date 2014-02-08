class @PrivateMessage extends Backbone.Model
  initialize: =>
    @clear()

  add: (username, message, opts = {}) =>
    @trigger("receive", @id, username, message, opts)

    log = @get('log')
    log.push({username, message, opts})

    # todo: Do not hardcode max log length
    # Trim the log size. Use 2x log length to reduce how often this happens
    if log.length > 100
      log.splice(0, log.length - 50)

  clear: =>
    @set('log', [])

  openChallenge: (args...) =>
    @trigger("openChallenge", args...)

  cancelChallenge: (args...) =>
    @trigger("cancelChallenge", args...)

  closeChallenge: (args...) =>
    @trigger("closeChallenge", args...)

  getLog: =>
    log = @get('log')
    if log.length > 50
      log.splice(0, log.length - 50)

    log

