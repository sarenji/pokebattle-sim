{moves} = require('../data/bw')
{Battle, Pokemon, Status, VolatileStatus, Attachment} = require('../').server
{Factory} = require './factory'
should = require 'should'
shared = require './shared'

require './helpers'

describe 'BattleController', ->
  it "automatically ends the turn if all players move", ->
    shared.create.call(this)
    mock = @sandbox.mock(@controller)
    mock.expects('continueTurn').once()
    @controller.makeMove(@player1, 'Tackle')
    @controller.makeMove(@player2, 'Tackle')
    mock.verify()

  it "automatically ends the turn if all players switch", ->
    shared.create.call this,
      team1: [Factory('Hitmonchan'), Factory('Heracross')]
      team2: [Factory('Hitmonchan'), Factory('Heracross')]
    mock = @sandbox.mock(@controller)
    mock.expects('continueTurn').once()
    @controller.makeSwitch(@player1, 1)
    @controller.makeSwitch(@player2, 1)
    mock.verify()

  describe "switch validations", ->
    it "rejects switches under 0", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [0..2]))
      mock = @sandbox.mock(@battle).expects('recordSwitch').never()
      @controller.makeSwitch(@player1, -1)
      mock.verify()

    it "rejects switches for pokemon who are already out", ->
      shared.create.call this,
        numActive: 2
        team1: (Factory("Magikarp")  for x in [0..2])
      mock = @sandbox.mock(@battle).expects('recordSwitch').never()
      @controller.makeSwitch(@player1, 0)
      @controller.makeSwitch(@player1, 1)
      mock.verify()

    it "rejects switches over the max team party index", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [0..2]))
      mock = @sandbox.mock(@battle).expects('recordSwitch').never()
      @controller.makeSwitch(@player1, 3)
      mock.verify()

    it "accepts switches between active pokemon and max team party index", ->
      shared.create.call this,
        numActive: 2
        team1: (Factory("Magikarp")  for x in [0..2])
      mock = @sandbox.mock(@battle).expects('recordSwitch').once()
      @controller.makeSwitch(@player1, 2)
      mock.verify()

  describe "move validations", ->
    it "rejects moves not part of the pokemon's move", ->
      shared.create.call this,
        team1: [ Factory("Magikarp", moves: ["Tackle", "Splash"]) ]
        mock = @sandbox.mock(@battle).expects('recordMove').never()
      @controller.makeMove(@player1, "EXTERMINATE")
      mock.verify()
