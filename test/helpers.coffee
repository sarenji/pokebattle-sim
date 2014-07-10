sinon = require 'sinon'
redis = require '../server/redis'

process.env.NODE_ENV = 'test'

beforeEach ->
  @sandbox = sinon.sandbox.create()
  @clock = sinon.useFakeTimers()
  @stubSpark = ->
    {send: (->), end: (->)}

afterEach (done) ->
  @clock.restore()
  @sandbox.restore()
  redis.flushdb(done)
