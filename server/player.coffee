class @Player
  constructor: (@socket, @team) ->
    {@id, @username} = @socket

  updateChat: (username, message) =>
    @emit 'updatechat', username, message

  requestAction: (id, validActions) =>
    @emit 'request action', id, validActions

  attachToTeam: (attachment) =>
    @team.attach(attachment)

  hasAttachment: (attachment) =>
    @team.hasAttachment(attachment)

  getAttachment: (attachment) =>
    @team.getAttachment(attachment)

  # Used in battle#performMove
  # TODO: Maybe handle this better.
  isFainted: =>
    false

  emit: (args...) =>
    @socket.emit? args...
