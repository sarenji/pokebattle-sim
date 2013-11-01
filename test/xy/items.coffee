{Item} = require('../../server/bw/data/items')
{Pokemon} = require '../../server/bw/pokemon'
{Attachment, Status} = require '../../server/bw/attachment'
{Move} = require '../../server/bw/move'
{Factory} = require '../factory'
util = require '../../server/bw/util'
should = require 'should'
{_} = require 'underscore'
shared = require '../shared'

require '../helpers'

describe "XY Items:", ->
  describe "Weakness Policy", ->
    it "raises Attack and Sp. Attack by 2 if hit by a super-effective move", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Weakness Policy')]
      thunderbolt = @battle.getMove("Thunderbolt")
      @p1.stages.should.include(attack: 0, specialAttack: 0)
      @battle.performMove(@id2, thunderbolt)
      @p1.stages.should.include(attack: 2, specialAttack: 2)

    it "is consumed after use", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Weakness Policy')]
      thunderbolt = @battle.getMove("Thunderbolt")
      @battle.performMove(@id2, thunderbolt)
      @p1.hasItem().should.be.false

    it "is not used if hit by a non-super-effective move", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Weakness Policy')]
      ember = @battle.getMove("Ember")
      @battle.performMove(@id2, ember)
      @p1.hasItem().should.be.true
      @p1.stages.should.include(attack: 0, specialAttack: 0)

    it "is not used if hit by a super-effective move that is non-damaging", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Weakness Policy')]
      thunderWave = @battle.getMove("Thunder Wave")
      @battle.performMove(@id2, thunderWave)
      @p1.hasItem().should.be.true
      @p1.stages.should.include(attack: 0, specialAttack: 0)
