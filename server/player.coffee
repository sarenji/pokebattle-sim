class @Player
  constructor: (@socket, @team) ->
    {@id, @username} = @socket

  updateChat: (username, message) ->
    @emit 'updatechat', username, message

  requestAction: (id, validActions) ->
    @emit 'request action', id, validActions

  attachToTeam: (attachment) ->
    @team.attach(attachment, team: @team)

  has: (attachment) ->
    @team.has(attachment)

  get: (attachment) ->
    @team.get(attachment)

  switch: (battle, index1, index2) ->
    @team.switch(battle, this, index1, index2)

  # Used in battle#performMove
  # TODO: Maybe handle this better.
  isFainted: ->
    false

  emit: (args...) ->
    @socket.emit? args...
