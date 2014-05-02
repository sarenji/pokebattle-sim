schedule = require('node-schedule')
ratings = require('./ratings')
redis = require('./redis')

DEFAULT_RATING = ratings.algorithm.createPlayer().rating
DECAY_AMOUNT = 10

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
      return  if err
      [ids, didDelete] = results
      ratings.getRatings ids, (err, oldRatings) ->
        return  if err
        newRatings = oldRatings.map (rating) ->
          if rating < DEFAULT_RATING
            rating
          else
            Math.max(rating - 10, DEFAULT_RATING)
        ratings.setRatings ids, newRatings, ->
          job.emit('finished')

  return jobs
