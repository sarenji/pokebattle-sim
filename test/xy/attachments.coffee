{Attachment, Status} = require '../../server/xy/attachment'
{Factory} = require '../factory'
shared = require '../shared'
should = require 'should'
require '../helpers'

describe "XY status:", ->
  describe "Sleep", ->
    it "does not reset upon switch out", ->
      shared.create.call(this, gen: 'xy')
      @p1.attach(Status.Sleep, turns: 3)
      @p1.get(Status.Sleep).counter.should.equal(0)
      @battle.performMove(@p1, @battle.getMove("Splash"))
      @p1.get(Status.Sleep).counter.should.equal(1)
      @p1.team.switchOut(@p1)
      @p1.get(Status.Sleep).counter.should.equal(1)

  describe "paralysis", ->
    it "does not affect electric pokemon", ->
      shared.create.call(this, team1: [Factory("Pikachu")], gen: 'xy')
      should.not.exist @p1.attach(Status.Paralyze)
