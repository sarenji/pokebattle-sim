{_} = require 'underscore'

LOG_KEY = "log"
LOG_MAX = 100
redis = require('./redis')

log = (message, context={}, next) ->
  context = _.extend({}, @context, context)
  obj = {message, context}
  objStr = JSON.stringify(obj)

  redis.lpush LOG_KEY, objStr, (err) ->
    return next(err) if err
    redis.ltrim LOG_KEY, 0, LOG_MAX, (err, count) ->
      return next(err)  if err
      next()  if err

  return objStr

withContext = (context) ->
  context = _.extend({}, @context, context)

  return {
    context: context
    log: log
    withContext: withContext
  }

@log = log
@withContext = withContext