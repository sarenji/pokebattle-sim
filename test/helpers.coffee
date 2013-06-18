sinon = require 'sinon'

beforeEach ->
  @sandbox = sinon.sandbox.create()

afterEach ->
  @sandbox.restore()
