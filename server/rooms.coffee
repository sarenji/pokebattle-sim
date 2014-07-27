{_} = require('underscore')
{EventEmitter} = require('events')
redis = require('./redis')
errors = require('../shared/errors')

class @Room extends EventEmitter
  constructor: (@name) ->
    @users = {}
    @userCounts = {}
    @sparks = []

  add: (spark) ->
    return  if spark in @sparks
    @send('joinChatroom', @name, @userJSON(spark.user))  unless @users[spark.user.id]
    @sparks.push(spark)

    userId = spark.user.id
    if userId not of @users
      @userCounts[userId] = 1
      @users[userId] = spark.user
    else
      @userCounts[userId] += 1
    spark.send('listChatroom', @name, @toJSON())

  remove: (spark) ->
    index = @sparks.indexOf(spark)
    return  if index == -1
    @sparks.splice(index, 1)

    userId = spark.user.id
    @userCounts[userId] -= 1
    if @userCounts[userId] == 0
      @send('leaveChatroom', @name, @transformName(spark.user.name))
      delete @users[userId]
      delete @userCounts[userId]

  userMessage: (user, message) ->
    @send('userMessage', @name, @transformName(user.name), message)

  message: (message) ->
    @send('rawMessage', @name, message)

  announce: (klass, message) ->
    @send('announce', @name, klass, message)

  send: ->
    user.send.apply(user, arguments)  for name, user of @users

  userJSON: (user) ->
    json = user.toJSON(alt: @transformName(user.name))

  # Hook to transform a user's name to something else. Does the identity func.
  transformName: (name) ->
    name

  # Set the room's topic. Does not work for battle rooms.
  # TODO: Or rather, it shouldn't work for battle rooms. Once a distinction is
  # possible, block it for battle rooms
  setTopic: (topic) ->
    redis.hset "topic", "main", topic
    @send('topic', topic)  if topic

  toJSON: ->
    for name, user of @users
      @userJSON(user)
