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

  switch: (pokemon, toIndex) ->
    @team.switch(pokemon, toIndex)

  send: (args...) ->
    @user.send? args...

  toJSON: ->
    if @user.toJSON
      @user.toJSON()
    else
      {@id}
