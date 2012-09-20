sinon = require 'sinon'
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
