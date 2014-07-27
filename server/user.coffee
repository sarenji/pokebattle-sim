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

  toJSON: (options = {}) ->
    displayedName = options.alt ? @name
    isAlt = (displayedName != @name)
    json = {
      'id': displayedName
    }
    if isAlt
      json['isAlt'] = true
    else
      json['authority'] = @authority  if @authority
    json

  send: ->
    spark.send.apply(spark, arguments)  for spark in @sparks

  error: (args...) ->
    @send("errorMessage", args...)

  message: (roomId, msg) ->
    @send("rawMessage", roomId, msg)

  announce: (roomId, klass, msg) ->
    @send("announce", roomId, klass, msg)

  close: ->
    spark.end()  for spark in @sparks
