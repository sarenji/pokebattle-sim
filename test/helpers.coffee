sinon = require 'sinon'

process.env.NODE_ENV = 'test'

beforeEach ->
  @sandbox = sinon.sandbox.create()

afterEach ->
  @sandbox.restore()
