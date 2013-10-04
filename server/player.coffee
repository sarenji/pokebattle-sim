class @Player
  constructor: (@user) ->
    @id = @user.id
    @queue = []

  tell: (args...) ->
    @queue.push(args)

  attachToTeam: (attachment) ->
    @team.attach(attachment, team: @team)

  shouldBlockFieldExecution: (move, user) ->
    @team.shouldBlockFieldExecution(move, user)

  has: (attachment) ->
    @team.has(attachment)

  get: (attachment) ->
    @team.get(attachment)

  switch: (index1, index2) ->
    @team.switch(this, index1, index2)

  send: (args...) ->
    @user.send? args...

  toJSON: ->
    if @user.toJSON
      @user.toJSON()
    else
      {@id}
