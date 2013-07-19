class @Player
  constructor: (@socket, @team) ->
    {@id, @username} = @socket

  updateChat: (username, message) ->
    @send 'updatechat', username, message

  requestAction: (id, validActions) ->
    @send 'request action', id, validActions, @team.toJSON()

  attachToTeam: (attachment) ->
    @team.attach(attachment, team: @team)

  has: (attachment) ->
    @team.has(attachment)

  get: (attachment) ->
    @team.get(attachment)

  switch: (index1, index2) ->
    @team.switch(this, index1, index2)

  # Used in battle#performMove
  # TODO: Maybe handle this better.
  isFainted: ->
    false

  send: (args...) ->
    @socket.send? args...
