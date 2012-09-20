sinon = require 'sinon'
{items, moves} = require('../../data/bw')
{Factory} = require '../factory'
should = require 'should'
{_} = require 'underscore'
shared = require '../shared'

@test = ->
  describe "leftovers", ->
    it "heals 1/16 of a pokemon's HP at the end of a turn", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Leftovers')]
      @team1.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')
      amount = Math.floor(@team1.at(0).stat('hp') / 16)
      @team1.at(0).currentHP.should.equal(1 + amount)

  describe "muscle band", ->
    it "increases base power of physical moves by 0x1199", ->
      shared.create.call(this)
      move = moves['tackle']
      modifier = items['Muscle Band'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1199

      move = moves['shadow-ball']
      modifier = items['Muscle Band'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

  describe "Wise Glasses", ->
    it "increases base power of special moves by 0x1199", ->
      shared.create.call(this)
      move = moves['tackle']
      modifier = items['Wise Glasses'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

      move = moves['shadow-ball']
      modifier = items['Wise Glasses'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1199
