sinon = require 'sinon'

process.env.NODE_ENV = 'test'

beforeEach ->
  @sandbox = sinon.sandbox.create()
  @clock = sinon.useFakeTimers()

afterEach ->
  @clock.restore()
  @sandbox.restore()
