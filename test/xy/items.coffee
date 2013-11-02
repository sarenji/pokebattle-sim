{Item} = require('../../server/xy/data/items')
{Pokemon} = require '../../server/xy/pokemon'
{Attachment, Status} = require '../../server/xy/attachment'
{Move} = require '../../server/xy/move'
{Factory} = require '../factory'
util = require '../../server/xy/util'
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

  describe "Assault Vest", ->
    it "blocks non-damaging moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Assault Vest')]
      splash = @battle.getMove("Splash")
      @p1.isMoveBlocked(splash).should.be.true

    it "doesn't block damaging moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Assault Vest')]
      tackle = @battle.getMove("Tackle")
      @p1.isMoveBlocked(tackle).should.be.false

    it "raises special defense by 1.5", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp')]
      spDef = @p1.stat('specialDefense')
      @p1.setItem(Item.AssaultVest)
      @p1.stat('specialDefense').should.equal Math.floor(spDef * 1.5)
