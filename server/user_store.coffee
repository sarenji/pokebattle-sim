{EventEmitter} = require('events')
{User} = require('./user')

class @UserStore extends EventEmitter
  constructor: ->
    super()
    @users = {}

  add: (json, spark) ->
    id = json.name || json
    user = (@users[@key(id)] ||= new User(json))
    user.addSpark(spark)
    user

  remove: (spark) ->
    id = @key(spark.user.name)
    user = @users[id]
    if user
      user.removeSpark(spark)
      delete @users[id]  unless user.hasSparks()
    return user

  contains: (id) ->
    @get(id)?

  get: (id) ->
    @users[@key(id)]

  getUsers: ->
    (user  for key, user of @users)

  key: (id) ->
    String(id).toLowerCase()

  send: ->
    for key, user of @users
      user.send.apply(user, arguments)

  toJSON: ->
    for key, user of @users
      user.toJSON()
