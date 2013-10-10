{Battle} = require('../../server/bw/battle')
{Pokemon} = require('../../server/bw/pokemon')
{Status, VolatileStatus, Attachment} = require('../../server/bw/attachment')
{Player} = require('../../server/player')
{Conditions} = require '../../server/conditions'
{Factory} = require '../factory'
should = require 'should'
shared = require '../shared'
require '../helpers'

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

    it "rejects switches that are not part of the request action", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [0..2]))
      @p1.blockSwitch()
      @p1.resetBlocks = ->
      @battle.removeRequest(@id1)
      @battle.beginTurn()

      mock = @sandbox.mock(@battle).expects('recordSwitch').never()
      @controller.makeSwitch(@player1, 2)
      mock.verify()

    it "rejects switches if the battle has not started yet", ->
      shared.build(this, team1: (Factory("Magikarp")  for x in [0..2]))

      mock = @sandbox.mock(@battle).expects('recordSwitch').never()
      @controller.makeSwitch(@player1, 2)
      mock.verify()

    it "rejects switches not for a specific turn", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [0..2]))

      mock = @sandbox.mock(@battle).expects('recordMove').never()
      @controller.makeSwitch(@player1, 2)
      mock.verify()

  describe "move validations", ->
    it "rejects moves not part of the pokemon's valid moves", ->
      shared.create.call this,
        team1: [ Factory("Magikarp", moves: ["Tackle", "Splash"]) ]
      mock = @sandbox.mock(@battle).expects('recordMove').never()
      @controller.makeMove(@player1, "EXTERMINATE")
      mock.verify()

    it "accepts Struggle", ->
      shared.create.call this,
        team1: [ Factory("Magikarp", moves: ["Tackle", "Splash"]) ]
      @p1.blockMove(move)  for move in @p1.moves
      @p1.resetBlocks = ->
      @battle.removeRequest(@id1)
      @battle.beginTurn()

      mock = @sandbox.mock(@battle).expects('recordMove').once()
      @controller.makeMove(@player1, "Struggle")
      mock.verify()

    it "rejects moves that cannot be selected", ->
      shared.create.call this,
        team1: [ Factory("Magikarp", moves: ["Tackle", "Splash"]) ]
      move = @p1.moves[0]
      @p1.blockMove(move)
      @p1.resetBlocks = ->
      @battle.removeRequest(@id1)
      @battle.beginTurn()

      mock = @sandbox.mock(@battle).expects('recordMove').never()
      @controller.makeMove(@player1, move.name)
      mock.verify()

    it "rejects moves if the battle has not started yet", ->
      shared.build this,
        team1: [ Factory("Magikarp", moves: ["Tackle", "Splash"]) ]

      mock = @sandbox.mock(@battle).expects('recordMove').never()
      @controller.makeMove(@player1, @p1.moves[0].name)
      mock.verify()

    it "rejects moves not for a specific turn", ->
      shared.create.call this,
        team1: [ Factory("Magikarp", moves: ["Tackle", "Splash"]) ]

      mock = @sandbox.mock(@battle).expects('recordMove').never()
      @controller.makeMove(@player1, @p1.moves[0].name, null, @battle.turn - 1)
      mock.verify()

  describe "conditions:", ->
    describe "Team Preview", ->
      it "starts the battle by passing team info and requesting team order", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        shared.build(this, {conditions})
        mock = @sandbox.mock(@battle).expects('begin').never()
        @controller.beginBattle()
        mock.verify()

      it "waits until all players have arranged their teams before starting", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        shared.build(this, {conditions})
        mock = @sandbox.mock(@battle).expects('begin').never()
        @controller.beginBattle()
        @controller.arrangeTeam(@player1, [ 0 ])
        mock.verify()
        @battle.begin.restore()

        mock = @sandbox.mock(@battle).expects('begin').once()
        @controller.arrangeTeam(@player2, [ 0 ])
        mock.verify()

      it "rejects team arrangements that aren't arrays", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        shared.create.call(this, {conditions})
        arrangement = true
        @controller.arrangeTeam(@player1, arrangement).should.be.false

      it "accepts arrays of integers (arrangements) matching team length", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        shared.create.call(this, {conditions})
        arrangement = [ 0 ]
        @controller.arrangeTeam(@player1, arrangement).should.be.true

      it "rejects team arrangements that are smaller than the team length", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        shared.create.call(this, {conditions})
        arrangement = []
        @controller.arrangeTeam(@player1, arrangement).should.be.false

      it "rejects team arrangements that are larger than the team length", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        shared.create.call(this, {conditions})
        arrangement = [ 0, 1 ]
        @controller.arrangeTeam(@player1, arrangement).should.be.false

      it "rejects team arrangements containing negative indices", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        shared.create.call(this, {conditions})
        arrangement = [ -1 ]
        @controller.arrangeTeam(@player1, arrangement).should.be.false

      it "rejects team arrangements containing indices out of bounds", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        shared.create.call(this, {conditions})
        arrangement = [ 1 ]
        @controller.arrangeTeam(@player1, arrangement).should.be.false

      it "rejects team arrangements containing non-unique indices", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        team1 = (Factory("Magikarp")  for x in [0..1])
        shared.create.call(this, {conditions, team1})
        arrangement = [ 1, 1 ]
        @controller.arrangeTeam(@player1, arrangement).should.be.false

      it "rejects team arrangements that have some non-numbers", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        team1 = (Factory("Magikarp")  for x in [0..1])
        shared.create.call(this, {conditions, team1})
        arrangement = [ 1, "a" ]
        @controller.arrangeTeam(@player1, arrangement).should.be.false

      it "rejects team arrangements that don't point to a correct index", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        team1 = (Factory("Magikarp")  for x in [0..1])
        shared.create.call(this, {conditions, team1})
        arrangement = [ 1, .5 ]
        @controller.arrangeTeam(@player1, arrangement).should.be.false

      it "rejects team arrangements if the battle has already begun", ->
        team1 = (Factory("Magikarp")  for x in [0..1])
        shared.create.call(this, {team1})
        arrangement = [ 1, 0 ]
        @controller.arrangeTeam(@player1, arrangement).should.be.false

      it "rearranges team when given a valid array of indices", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        team1 = [ Factory("Magikarp"), Factory("Gyarados"), Factory("Celebi") ]
        team2 = [ Factory("Magikarp"), Factory("Gyarados"), Factory("Celebi") ]
        shared.create.call(this, {conditions, team1, team2})
        @controller.arrangeTeam(@player1, [ 0, 2, 1 ])
        @controller.arrangeTeam(@player2, [ 2, 0, 1 ])
        @team1.at(0).name.should.equal("Magikarp")
        @team1.at(1).name.should.equal("Celebi")
        @team1.at(2).name.should.equal("Gyarados")
        @team2.at(0).name.should.equal("Celebi")
        @team2.at(1).name.should.equal("Magikarp")
        @team2.at(2).name.should.equal("Gyarados")

      it "shows the team preview for new spectators", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        shared.create.call(this, {conditions})
        spectator = new Player(id: "scouter")
        length = @battle.spectators.length
        spy = @sandbox.spy(spectator, 'send')
        @controller.addSpectator(spectator)
        spy.calledWith('team preview').should.be.true

      it "does not show the team preview if the battle is done arranging", ->
        conditions = [ Conditions.TEAM_PREVIEW ]
        shared.create.call(this, {conditions})
        @controller._beginBattle()
        spectator = new Player(id: "scouter")
        length = @battle.spectators.length
        spy = @sandbox.spy(spectator, 'send')
        @controller.addSpectator(spectator)
        spy.calledWith('team preview').should.be.false
