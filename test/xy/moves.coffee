{Attachment, Status} = require('../../server/xy/attachment')
{Battle} = require('../../server/xy/battle')
{Pokemon} = require('../../server/xy/pokemon')
{Weather} = require('../../server/xy/weather')
{Move} = require('../../server/xy/move')
util = require '../../server/xy/util'
{Protocol} = require '../../shared/protocol'
{Factory} = require '../factory'
should = require 'should'
{_} = require 'underscore'
shared = require '../shared'

require '../helpers'

describe "XY Moves:", ->
  describe "a critical hit", ->
    it "multiplies damage by 1.5x", ->
      Move::criticalMultiplier.should.equal(1.5)

  describe "Dragon Pulse", ->
    it "has 85 base power now", ->
      shared.create.call(this, gen: 'xy')
      @battle.getMove('Dragon Pulse').power.should.equal(85)

  describe 'Hidden Power', ->
    it "always has 60 base power", ->
      shared.create.call(this, gen: 'xy')
      hiddenPower = @battle.getMove('Hidden Power')
      hiddenPower.power.should.equal(60)
      hiddenPower.basePower(@battle, @p1, @p2).should.equal(60)

  describe "Facade", ->
    it "does not cut attack in half when burned", ->
      shared.create.call(this, gen: 'xy')
      facade = @battle.getMove('Facade')
      facade.burnCalculation(@p1).should.equal(1)
      @p1.attach(Status.Burn)
      facade.burnCalculation(@p1).should.equal(1)
