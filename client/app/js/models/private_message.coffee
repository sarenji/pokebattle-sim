MAX_LOG_LENGTH = 50

class @PrivateMessage extends Backbone.Model
  initialize: =>
    @clear()
    @set('notifications', 0)

  add: (username, message, opts = {}) =>
    @set('notifications', @get('notifications') + 1)  if username == @id
    @trigger("receive", this, @id, username, message, opts)

    log = @get('log')
    log.push({username, message, opts})

    # todo: Do not hardcode max log length
    # Trim the log size. Use 2x log length to reduce how often this happens
    if log.length > (2 * MAX_LOG_LENGTH)
      log.splice(0, log.length - MAX_LOG_LENGTH)

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

