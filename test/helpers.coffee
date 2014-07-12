sinon = require 'sinon'
redis = require '../server/redis'
{EventEmitter} = require 'events'

process.env.NODE_ENV = 'test'

beforeEach ->
  @sandbox = sinon.sandbox.create()
  @clock = sinon.useFakeTimers()
  @stubSpark = ->
    ee = new EventEmitter()
    ee.send = (->)
    ee.end  = (-> @emit('end'))
    ee

afterEach (done) ->
  @clock.restore()
  @sandbox.restore()
  redis.flushdb(done)
