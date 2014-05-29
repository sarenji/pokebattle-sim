MAX_LOG_LENGTH = 50

class @PrivateMessage extends Backbone.Model
  initialize: =>
    @loadLog()
    @set('notifications', 0)

  add: (username, message, opts = {}) =>
    @set('notifications', @get('notifications') + 1)  if username == @id
    @trigger("receive", this, @id, username, message, opts)

    log = @get('log')
    log.push({username, message, opts})

    # Trim the log size. Use 2x log length to reduce how often this happens
    if log.length > (2 * MAX_LOG_LENGTH)
      log.splice(0, log.length - MAX_LOG_LENGTH)

    @saveLog()

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
    return log

  loadLog: =>
    try
      log = JSON.parse(window.localStorage.getItem(@logKey())) || []
      @set('log', log)
    catch
      @set('log', [])

  saveLog: =>
    try
      window.localStorage.setItem(@logKey(), JSON.stringify(@getLog()))

  logKey: =>
    key = [ @id, PokeBattle.username ]
    key.sort()
    key.join(':')
