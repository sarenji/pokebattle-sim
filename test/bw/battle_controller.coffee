require '../helpers'

{Factory} = require '../factory'
should = require 'should'
shared = require '../shared'

describe 'BattleController', ->
  it "automatically ends the turn if all players move", ->
    shared.create.call(this)
    mock = @sandbox.mock(@controller)
    mock.expects('continueTurn').once()
    @controller.makeMove(@id1, 'Tackle')
    @controller.makeMove(@id2, 'Tackle')
    mock.verify()

  it "automatically ends the turn if all players switch", ->
    shared.create.call this,
      team1: [Factory('Hitmonchan'), Factory('Heracross')]
      team2: [Factory('Hitmonchan'), Factory('Heracross')]
    mock = @sandbox.mock(@controller)
    mock.expects('continueTurn').once()
    @controller.makeSwitch(@id1, 1)
    @controller.makeSwitch(@id2, 1)
    mock.verify()

  describe "switch validations", ->
    it "rejects switches under 0", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [0..2]))
      mock = @sandbox.mock(@battle).expects('recordSwitch').never()
      @controller.makeSwitch(@id1, -1)
      mock.verify()

    it "rejects switches for pokemon who are already out", ->
      shared.create.call this,
        numActive: 2
        team1: (Factory("Magikarp")  for x in [0..2])
      mock = @sandbox.mock(@battle).expects('recordSwitch').never()
      @controller.makeSwitch(@id1, 0)
      @controller.makeSwitch(@id1, 1)
      mock.verify()

    it "rejects switches over the max team party index", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [0..2]))
      mock = @sandbox.mock(@battle).expects('recordSwitch').never()
      @controller.makeSwitch(@id1, 3)
      mock.verify()

    it "accepts switches between active pokemon and max team party index", ->
      shared.create.call this,
        numActive: 2
        team1: (Factory("Magikarp")  for x in [0..2])
      mock = @sandbox.mock(@battle).expects('recordSwitch').once()
      @controller.makeSwitch(@id1, 2)
      mock.verify()

    it "rejects switches that are not part of the request action", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [0..2]))
      @p1.blockSwitch()
      @p1.resetBlocks = ->
      @battle.removeRequest(@id1)
      @battle.beginTurn()

      mock = @sandbox.mock(@battle).expects('recordSwitch').never()
      @controller.makeSwitch(@id1, 2)
      mock.verify()

    it "rejects switches if the battle has not started yet", ->
      shared.build(this, team1: (Factory("Magikarp")  for x in [0..2]))

      mock = @sandbox.mock(@battle).expects('recordSwitch').never()
      @controller.makeSwitch(@id1, 2)
      mock.verify()

    it "rejects switches not for a specific turn", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [0..2]))

      mock = @sandbox.mock(@battle).expects('recordMove').never()
      @controller.makeSwitch(@id1, 2)
      mock.verify()

    it "rejects switches for a player who doesn't exist", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [0..2]))

      @controller.makeSwitch("fake dude", 2).should.be.false

  describe "move validations", ->
    it "rejects moves not part of the pokemon's valid moves", ->
      shared.create.call this,
        team1: [ Factory("Magikarp", moves: ["Tackle", "Splash"]) ]
      mock = @sandbox.mock(@battle).expects('recordMove').never()
      @controller.makeMove(@id1, "EXTERMINATE")
      mock.verify()

    it "accepts Struggle", ->
      shared.create.call this,
        team1: [ Factory("Magikarp", moves: ["Tackle", "Splash"]) ]
      @p1.blockMove(move)  for move in @p1.moves
      @p1.resetBlocks = ->
      @battle.removeRequest(@id1)
      @battle.beginTurn()

      mock = @sandbox.mock(@battle).expects('recordMove').once()
      @controller.makeMove(@id1, "Struggle")
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
      @controller.makeMove(@id1, move.name)
      mock.verify()

    it "rejects moves if the battle has not started yet", ->
      shared.build this,
        team1: [ Factory("Magikarp", moves: ["Tackle", "Splash"]) ]

      mock = @sandbox.mock(@battle).expects('recordMove').never()
      @controller.makeMove(@id1, @p1.moves[0].name)
      mock.verify()

    it "rejects moves not for a specific turn", ->
      shared.create.call this,
        team1: [ Factory("Magikarp", moves: ["Tackle", "Splash"]) ]

      mock = @sandbox.mock(@battle).expects('recordMove').never()
      @controller.makeMove(@id1, @p1.moves[0].name, null, @battle.turn - 1)
      mock.verify()

    it "rejects moves for a player who doesn't exist", ->
      shared.create.call this,
        team1: [ Factory("Magikarp", moves: ["Tackle", "Splash"]) ]

      @controller.makeMove("fake dude", @p1.moves[0].name).should.be.false
