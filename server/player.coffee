class @Player
  constructor: (@socket, @team) ->
    {@id, @username} = @socket

  updateChat: (username, message) =>
    @emit 'updatechat', username, message

  requestAction: (id, validActions) =>
    @emit 'request action', id, validActions

  emit: (args...) =>
    @socket.emit? args...
