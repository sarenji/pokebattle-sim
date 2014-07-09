{_} = require 'underscore'

class @User
  constructor: (attributes) ->
    if _.isObject(attributes)
      {@id, @name, @authority} = attributes
    else
      @id = attributes
    @name ?= @id
    @sparks = []

  addSpark: (spark) ->
    unless @hasSpark(spark)
      @sparks.push(spark)
      spark.user = this

  removeSpark: (spark) ->
    index = @sparks.indexOf(spark)
    @sparks.splice(index, 1)  if index != -1

  hasSpark: (spark) ->
    spark in @sparks

  hasSparks: ->
    @sparks.length >= 1

  toJSON: ->
    json = {
      'id': @name
    }
    json['authority'] = @authority  if @authority
    json

  send: ->
    spark.send.apply(spark, arguments)  for spark in @sparks

  error: (args...) ->
    @send("errorMessage", args...)

  message: (msg) ->
    @send("rawMessage", msg)

  announce: (klass, msg) ->
    @send("announce", klass, msg)

  close: ->
    spark.end()  for spark in @sparks

  # Returns a new user object where the name has been masked (useful for alts)
  maskName: (name) ->
    return this  if name == @name

    # Copy over all properties.
    newUser = new User()
    newUser.original = this
    for key, value of this
      newUser[key] = value

    newUser.toJSON = ->
      json = @original.toJSON.apply(this, arguments)
      json.isAlt = true
      json.authority = undefined
      json

    newUser.name = name
    return newUser
