{Battle, Pokemon, Status, Attachment} = require('../').server
{Factory} = require './factory'
should = require 'should'
shared = require './shared'
{Protocol} = require '../shared/protocol'

require './helpers'

describe 'Mechanics', ->
  describe 'an attack missing', ->
    it 'deals no damage', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Magikarp')]
      shared.biasRNG.call(this, 'randInt', 'miss', 100)
      move = @battle.getMove('Leaf Storm')
      originalHP = @p2.currentHP
      @battle.performMove(@id1, @battle.getMove('Leaf Storm'))
      @p2.currentHP.should.equal(originalHP)

    it 'triggers effects dependent on the move missing', ->
      shared.create.call this,
        team1: [Factory('Hitmonlee')]
        team2: [Factory('Magikarp')]
      shared.biasRNG.call(this, 'randInt', 'miss', 100)
      hiJumpKick = @battle.getMove('Hi Jump Kick')
      mock = @sandbox.mock(hiJumpKick).expects('afterMiss').once()
      @battle.performMove(@id1, hiJumpKick)
      mock.verify()

    it 'does not trigger effects dependent on the move hitting', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      shared.biasRNG.call(this, 'randInt', 'miss', 100)
      hiJumpKick = @battle.getMove('Hi Jump Kick')
      mock = @sandbox.mock(hiJumpKick).expects('afterSuccessfulHit').never()
      @battle.performMove(@id1, hiJumpKick)
      mock.verify()

  describe 'fainting', ->
    it 'forces a new pokemon to be picked', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      spy = @sandbox.spy(@player2, 'tell')
      @p2.currentHP = 1
      @controller.makeMove(@player1, 'Psychic')
      @controller.makeMove(@player2, 'Mach Punch')
      spy.calledWith(Protocol.REQUEST_ACTIONS).should.be.true

    it 'does not increment the turn count', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      turn = @battle.turn
      @p2.currentHP = 1
      @controller.makeMove(@player1, 'Psychic')
      @controller.makeMove(@player2, 'Mach Punch')
      @battle.turn.should.not.equal turn + 1

    it 'removes the fainted pokemon from the action priority queue', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @p1.currentHP = 1
      @p2.currentHP = 1
      @controller.makeMove(@player1, 'Psychic')
      @controller.makeMove(@player2, 'Mach Punch')
      @p1.currentHP.should.be.below 1
      @p2.currentHP.should.equal 1
      action = @battle.getAction(@p1)
      should.not.exist(action)

    it 'lets the player switch in a new pokemon', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @p2.currentHP = 1
      @controller.makeMove(@player1, 'Psychic')
      @controller.makeMove(@player2, 'Mach Punch')
      @controller.makeSwitch(@player2, 1)
      @team2.first().name.should.equal 'Heracross'

  describe 'secondary effect attacks', ->
    it 'can inflict effect on successful hit', ->
      shared.create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Porygon-Z')]
      shared.biasRNG.call(this, 'next', 'secondary effect', 0)  # 100% chance
      spy = @sandbox.spy(@p2, 'attach')

      @battle.performMove(@id1, @battle.getMove('Iron Head'))
      spy.args[0][0].should.eql Attachment.Flinch

  describe 'secondary status attacks', ->
    it 'can inflict effect on successful hit', ->
      shared.create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Porygon-Z')]
      shared.biasRNG.call(this, "next", 'secondary status', 0)  # 100% chance
      @battle.performMove(@id1, @battle.getMove('Flamethrower'))
      @p2.has(Status.Burn).should.be.true

  describe 'the fang attacks', ->
    it 'can inflict two effects at the same time', ->
      shared.create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Gyarados')]
      shared.biasRNG.call(this, "next", "fang status", 0)  # 100% chance
      shared.biasRNG.call(this, "next", "fang flinch", 0)
      @battle.performMove(@id1, @battle.getMove("Ice Fang"))

      @p2.has(Attachment.Flinch).should.be.true
      @p2.has(Status.Freeze).should.be.true

  describe 'a pokemon with technician', ->
    it "doesn't increase damage if the move has bp > 60", ->
      shared.create.call this,
        team1: [Factory('Hitmontop')]
        team2: [Factory('Mew')]
      icePunch = @battle.getMove('Ice Punch')
      icePunch.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

    it "increases damage if the move has bp <= 60", ->
      shared.create.call this,
        team1: [Factory('Hitmontop')]
        team2: [Factory('Shaymin')]
      bulletPunch = @battle.getMove('Bullet Punch')
      bulletPunch.modifyBasePower(@battle, @p1, @p2).should.equal(0x1800)

  describe 'STAB', ->
    it "gets applied if the move and user share a type", ->
      shared.create.call this,
        team1: [Factory('Heracross')]
        team2: [Factory('Regirock')]
      megahorn = @battle.getMove("Megahorn")
      megahorn.stabModifier(@battle, @p1, @p2).should.equal(0x1800)

    it "doesn't get applied if the move and user are of different types", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      icePunch = @battle.getMove("Ice Punch")
      icePunch.stabModifier(@battle, @p1, @p2).should.equal(0x1000)

  describe 'turn order', ->
    it 'randomly decides winner if pokemon have the same speed and priority', ->
      shared.create.call this,
        team1: [Factory('Mew')]
        team2: [Factory('Mew')]
      spy = @sandbox.spy(@battle, 'determineTurnOrder')
      shared.biasRNG.call(this, "next", "turn order", .6)
      @battle.recordMove(@id1, @battle.getMove('Psychic'))
      @battle.recordMove(@id2, @battle.getMove('Psychic'))
      @battle.determineTurnOrder().should.eql [
        {id: @id2, pokemon: @p2, priority: 0}
        {id: @id1, pokemon: @p1, priority: 0}
      ]

      @battle.priorityQueue = null
      @battle.pokemonActions = []

      shared.biasRNG.call(this, "next", "turn order", .4)
      @battle.recordMove(@id1, @battle.getMove('Psychic'))
      @battle.recordMove(@id2, @battle.getMove('Psychic'))
      @battle.determineTurnOrder().should.eql [
        {id: @id1, pokemon: @p1, priority: 0}
        {id: @id2, pokemon: @p2, priority: 0}
      ]

    it 'decides winner by highest priority move', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Hitmonchan')]
      spy = @sandbox.spy(@battle, 'determineTurnOrder')
      @battle.recordMove(@id1, @battle.getMove('Mach Punch'))
      @battle.recordMove(@id2, @battle.getMove('Psychic'))
      @battle.determineTurnOrder().should.eql [
        {id: @id1, pokemon: @p1, priority: 1}
        {id: @id2, pokemon: @p2, priority: 0}
      ]

      @battle.priorityQueue = null
      @battle.pokemonActions = []

      @battle.recordMove(@id1, @battle.getMove('Psychic'))
      @battle.recordMove(@id2, @battle.getMove('Mach Punch'))
      @battle.determineTurnOrder().should.eql [
        {id: @id2, pokemon: @p2, priority: 1}
        {id: @id1, pokemon: @p1, priority: 0}
      ]

    it 'decides winner by speed if priority is equal', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Hitmonchan', evs: { speed: 4 })]
      @battle.recordMove(@id1, @battle.getMove('ThunderPunch'))
      @battle.recordMove(@id2, @battle.getMove('ThunderPunch'))
      @battle.determineTurnOrder().should.eql [
        {id: @id2, pokemon: @p2, priority: 0}
        {id: @id1, pokemon: @p1, priority: 0}
      ]

  describe 'fainting all the opposing pokemon', ->
    it "doesn't request any more actions from players", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @p2.currentHP = 1
      @controller.makeMove(@player1, 'Mach Punch')
      @controller.makeMove(@player2, 'Psychic')
      @battle.requests.should.not.have.property @player1.id
      @battle.requests.should.not.have.property @player2.id

    it 'ends the battle', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @p2.currentHP = 1
      mock = @sandbox.mock(@controller)
      mock.expects('endBattle').once()
      @controller.makeMove(@player1, 'Mach Punch')
      @controller.makeMove(@player2, 'Psychic')
      mock.verify()

  describe 'a pokemon with a type immunity', ->
    it 'cannot be damaged by a move of that type', ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Gyarados')]
      @controller.makeMove(@player1, 'Earthquake')
      @controller.makeMove(@player2, 'Dragon Dance')

      @p2.currentHP.should.equal @p2.stat('hp')

  describe 'a confused pokemon', ->
    it "has a 50% chance of hurting itself", ->
      shared.create.call(this)

      shared.biasRNG.call(this, "randInt", 'confusion turns', 1)  # always 1 turn
      @p1.attach(Attachment.Confusion, {@battle})
      shared.biasRNG.call(this, "next", 'confusion', 0)  # always hits

      mock = @sandbox.mock(@battle.getMove('Tackle'))
      mock.expects('execute').never()

      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      mock.verify()

      @p1.currentHP.should.be.lessThan @p1.stat('hp')
      @p2.currentHP.should.equal @p2.stat('hp')

    it "snaps out of confusion after a predetermined number of turns", ->
      shared.create.call(this)

      shared.biasRNG.call(this, "randInt", 'confusion turns', 1)  # always 1 turn
      @p1.attach(Attachment.Confusion)

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @p1.has(Attachment.Confusion).should.be.false

    it "will not crit the confusion recoil", ->
      shared.create.call(this)

      @p1.attach(Attachment.Confusion)
      shared.biasRNG.call(this, "next", 'confusion', 0)  # always recoils
      shared.biasRNG.call(this, 'next', 'ch', 0) # always crits

      spy = @sandbox.spy(@battle.confusionMove, 'isCriticalHit')
      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Tackle')

      spy.returned(false).should.be.true

  describe 'a frozen pokemon', ->
    it "will not execute moves", ->
      shared.create.call(this)
      @p1.attach(Status.Freeze)
      shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen

      mock = @sandbox.mock(@battle.getMove('Tackle'))
      mock.expects('execute').never()

      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      mock.verify()

    it "has a 20% chance of unfreezing", ->
      shared.create.call(this)
      @p1.attach(Status.Freeze)
      shared.biasRNG.call(this, "next", 'unfreeze chance', 0)  # always unfreezes

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @p1.has(Status.Freeze).should.be.false

    it "unfreezes if hit by a fire move", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen
      @p1.attach(Status.Freeze)

      @battle.performMove(@id2, @battle.getMove('Flamethrower'))
      @p1.has(Status.Freeze).should.be.false

    it "does not unfreeze if hit by a non-damaging move", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen
      @p1.attach(Status.Freeze)

      @battle.performMove(@id2, @battle.getMove('Will-O-Wisp'))
      @p1.has(Status.Freeze).should.be.true

    for moveName in ["Sacred Fire", "Flare Blitz", "Flame Wheel", "Fusion Flare", "Scald"]
      it "automatically unfreezes if using #{moveName}", ->
        shared.create.call(this)

        @p1.attach(Status.Freeze)
        shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen

        @battle.performMove(@id1, @battle.getMove(moveName))
        @p1.has(Status.Freeze).should.be.false

  describe "a paralyzed pokemon", ->
    it "has a 25% chance of being fully paralyzed", ->
      shared.create.call(this)

      @p1.attach(Status.Paralyze)
      shared.biasRNG.call(this, "next", 'paralyze chance', 0)  # always stays frozen

      mock = @sandbox.mock(@battle.getMove('Tackle'))
      mock.expects('execute').never()

      @controller.makeMove(@player1, 'Tackle')
      @controller.makeMove(@player2, 'Splash')

      mock.verify()

    it "has its speed quartered", ->
      shared.create.call(this)

      speed = @p1.stat('speed')
      @p1.attach(Status.Paralyze)

      @p1.stat('speed').should.equal Math.floor(speed / 4)

  describe "a burned pokemon", ->
    it "loses 1/8 of its HP each turn", ->
      shared.create.call(this)
      @p1.attach(Status.Burn)
      hp = @p1.currentHP
      eighth = Math.floor(hp / 8)

      @battle.endTurn()
      (hp - @p1.currentHP).should.equal(eighth)

      @battle.endTurn()
      (hp - @p1.currentHP).should.equal(2 * eighth)

  describe "a sleeping pokemon", ->
    it "sleeps for 1-3 turns", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "randInt", 'sleep turns', 3)
      @p1.attach(Status.Sleep)
      tackle = @battle.getMove('Tackle')

      for i in [0...3]
        @battle.performMove(@id1, tackle)
        @p1.has(Status.Sleep).should.be.true

      @battle.performMove(@id1, tackle)
      @p1.has(Status.Sleep).should.be.false

    it "cannot move while asleep", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "randInt", 'sleep turns', 3)
      @p1.attach(Status.Sleep)
      tackle = @battle.getMove('Tackle')

      mock = @sandbox.mock(tackle).expects('execute').never()
      for i in [0...3]
        @battle.performMove(@id1, tackle)
      mock.verify()
      tackle.execute.restore()

      mock = @sandbox.mock(tackle).expects('execute').once()
      @battle.performMove(@id1, tackle)
      mock.verify()

    it "resets its counter when switching out", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      shared.biasRNG.call(this, "randInt", 'sleep turns', 1)
      @p1.attach(Status.Sleep)
      tackle = @battle.getMove('Tackle')

      @battle.performMove(@id1, tackle)
      @battle.performSwitch(@id1, 1)
      @battle.performSwitch(@id1, 1)
      @battle.performMove(@id1, tackle)
      @p1.has(Status.Sleep).should.be.true

  describe "a poisoned pokemon", ->
    it "loses 1/8 of its HP each turn", ->
      shared.create.call(this)
      @p1.attach(Status.Poison)
      hp = @p1.currentHP
      eighth = Math.floor(hp / 8)

      @battle.endTurn()
      (hp - @p1.currentHP).should.equal(eighth)

      @battle.endTurn()
      (hp - @p1.currentHP).should.equal(2 * eighth)

  describe "a badly poisoned pokemon", ->
    it "loses 1/16 of its HP the first turn", ->
      shared.create.call(this)
      @p1.attach(Status.Toxic)
      hp = @p1.currentHP

      @battle.endTurn()
      (hp - @p1.currentHP).should.equal(hp >> 4)

    it "loses x/16 of its HP where x is the number of turns up to 15", ->
      shared.create.call(this)
      @p1.attach(Status.Toxic)
      hp = @p1.currentHP
      fraction = (hp >> 4)

      for i in [1..16]
        @battle.endTurn()
        hpFraction = Math.min(hp * i, hp * 15)
        (hp - @p1.currentHP).should.equal(hpFraction >> 4)
        @p1.currentHP = hp

    it "resets its counter when switching out", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      @p1.attach(Status.Toxic)
      hp = @p1.currentHP

      @battle.endTurn()
      @battle.performSwitch(@id1, 1)
      @p1.currentHP = hp
      @battle.performSwitch(@id1, 1)
      @battle.endTurn()
      (hp - @p1.currentHP).should.equal(hp >> 4)

  describe "Pokemon#turnsActive", ->
    it "is 1 on start of battle", ->
      shared.create.call(this)
      @p1.turnsActive.should.equal 1

    it "is set to 0 when switching", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [1..2]))
      @p1.turnsActive = 4
      @team1.switch(@player1, 0, 1)
      @team1.first().turnsActive.should.equal 0

    it "increases by 1 when a turn ends", ->
      shared.create.call(this)
      @p1.turnsActive.should.equal 1

      @battle.endTurn()
      @p1.turnsActive.should.equal 2

  describe "A move with 0 PP", ->
    it "will not execute", ->
      shared.create.call(this)
      move = @p1.moves[0]
      @p1.setPP(move, 0)

      @sandbox.mock(move).expects('execute').never()
      @sandbox.mock(@p1).expects('beforeMove').never()
      @battle.performMove(@id1, move)
