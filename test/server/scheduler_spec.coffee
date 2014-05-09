sinon = require('sinon')
async = require('async')

ratings = require('../../server/ratings')
scheduler = require('../../server/schedule')

require '../helpers'

describe 'Scheduler', ->
  beforeEach ->
    date = new Date()
    date.setHours(23)
    date.setMinutes(59)
    date.setSeconds(59)
    # Get rid of existing clock
    @clock.restore()
    @clock = sinon.useFakeTimers(date.getTime())
    @jobs = scheduler.createScheduler()
    @callbacks = @jobs.map (job) ->
      (callback) -> job.on('finished', callback)

  it 'decays elo ratings', (done) ->
    players = ['guy', 'lady']
    oldRatings = [ 2000, 4000 ]
    oldGuyRating = 2000
    oldLadyRating = 4000
    ratings.setRatings players, oldRatings, =>
      async.parallel @callbacks, =>
        ratings.getRatings players, (err, newRatings) =>
          throw err  if err
          newRatings.should.eql(oldRatings.map((r) -> r - ratings.DECAY_AMOUNT))
          done()
      @clock.tick(2000)

  it 'does not decay the minimum rating possible', (done) ->
    minRating = ratings.algorithm.createPlayer().rating
    ratings.setRating 'sonic', minRating, =>
      async.parallel @callbacks, =>
        ratings.getRating 'sonic', (err, rating) =>
          throw err  if err
          rating.should.equal(minRating)
          done()
      @clock.tick(2000)

  it 'does not decay active players', (done) ->
    players = ['guy', 'lady']
    oldRatings = [ 2000, 4000 ]
    oldGuyRating = 2000
    oldLadyRating = 4000
    ratings.setActive players, =>
      ratings.setRatings players, oldRatings, =>
        async.parallel @callbacks, =>
          ratings.getRatings players, (err, newRatings) =>
            throw err  if err
            newRatings.should.eql(oldRatings)
            done()
        @clock.tick(2000)
