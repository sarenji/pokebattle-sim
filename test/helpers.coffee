sinon = require 'sinon'
db = require '../server/database'

process.env.NODE_ENV = 'test'

beforeEach ->
  @sandbox = sinon.sandbox.create()
  @clock = sinon.useFakeTimers()

afterEach (done) ->
  @clock.restore()
  @sandbox.restore()
  db.flushdb(done)
