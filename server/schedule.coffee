schedule = require('node-schedule')
ratings = require('./ratings')
{LADDER_FORMATS} = require('../shared/conditions')
redis = require('./redis')

DEFAULT_RATING = ratings.algorithm.createPlayer().rating

@createScheduler = ->
  jobs = []
  # Artificial Elo decay per day
  jobs.push schedule.scheduleJob hour: 0, minute: 0, second: 0, ->
    # TODO: Turn into a lua script
    for ladder in LADDER_FORMATS
      ratedKey = ['users:rated', ladder].join(':')
      activeKey = ['users:active', ladder].join(':')
      job = this
      multi = redis.multi()
      multi = multi.sdiff(ratedKey, activeKey)
      multi = multi.del(activeKey)
      multi.exec (err, results) ->
        throw new Error(err)  if err
        [ids, didDelete] = results
        return job.emit('finished')  if ids.length == 0
        ratings.getRatings ladder, ids, (err, oldRatings) ->
          throw new Error(err)  if err
          newRatings = oldRatings.map (rating) ->
            if rating < DEFAULT_RATING
              rating
            else
              Math.max(rating - ratings.DECAY_AMOUNT, DEFAULT_RATING)
          ratings.setRatings ladder, ids, newRatings, (err) ->
            throw new Error(err)  if err
            job.emit('finished')

  return jobs
