class @Player
  constructor: (@user) ->
    @id = @user.id
    @queue = []

  tell: (args...) ->
    @queue.push(args)

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
    @user.send? args...

  toJSON: ->
    @user.toJSON()
