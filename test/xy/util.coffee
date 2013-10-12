util = require '../../server/xy/util'
should = require 'should'
require '../helpers'

describe "XY utility functions:", ->
  it "inherits from BW", ->
    should.exist(util)
    util.should.have.property('printBoostMessage')

  it "adds a new Fairy type", ->
    should.exist(util.Type)
    should.exist(util.Type.FAIRY)

  it "adds strengths and weaknesses of the new Fairy type", ->
    util.typeEffectiveness("Fairy", [ "Dragon" ]).should.equal(2)
    util.typeEffectiveness("Dragon", [ "Fairy" ]).should.equal(0)

  it "removes Steel's resistances to Ghost", ->
    util.typeEffectiveness("Ghost", [ "Steel" ]).should.equal(1)

  it "removes Steel's resistances to Dark", ->
    util.typeEffectiveness("Dark", [ "Steel" ]).should.equal(1)
