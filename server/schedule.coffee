schedule = require('node-schedule')
ratings = require('./ratings')
redis = require('./redis')

DEFAULT_RATING = ratings.algorithm.createPlayer().rating

@createScheduler = ->
  jobs = []
  # Artificial Elo decay per day
  jobs.push schedule.scheduleJob hour: 0, minute: 0, second: 0, ->
    # TODO: Turn into a lua script
    job = this
    multi = redis.multi()
    multi = multi.sdiff('users:rated', 'users:active')
    multi = multi.del('users:active')
    multi.exec (err, results) ->
      throw new Error(err)  if err
      [ids, didDelete] = results
      return job.emit('finished')  if ids.length == 0
      ratings.getRatings ids, (err, oldRatings) ->
        throw new Error(err)  if err
        newRatings = oldRatings.map (rating) ->
          if rating < DEFAULT_RATING
            rating
          else
            Math.max(rating - ratings.DECAY_AMOUNT, DEFAULT_RATING)
        ratings.setRatings ids, newRatings, (err) ->
          throw new Error(err)  if err
          job.emit('finished')

  return jobs
