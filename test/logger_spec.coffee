require('./helpers')

should = require('should')
logger = require('../server/logger')
redis = require('../server/redis')

describe "Logger", ->
  describe "#log", ->
    it "writes to redis", ->
      logger.log "hello", {a: 1}, ->
        logger.log "hello2", {b: 2}, (err) ->
          should.not.exist(err)
          redis.llen "log", (err, result) ->
            result.should.equal(2)

  describe "#withContext", ->
    it "creates a new logger with modified context", ->
      stack1 = logger.withContext(a: 1)
      result = stack1.log("Hello", b: 2)
      result.should.eql(JSON.stringify({message: "Hello", context: {a: 1, b: 2}}))

    it "stacks contexts", ->
      stack1 = logger.withContext(a: 1)
      stack2 = stack1.withContext(b: 2)

      stack1.context.should.eql(a: 1)
      stack2.context.should.eql(a: 1, b: 2)
