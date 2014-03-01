require '../helpers'

{Battle} = require('../../server/bw/battle')
{Pokemon} = require('../../server/bw/pokemon')
{Status, Attachment} = require('../../server/bw/attachment')
{Conditions} = require '../../shared/conditions'
{Factory} = require '../factory'
should = require 'should'
shared = require '../shared'
{Protocol} = require '../../shared/protocol'

describe 'Mechanics', ->
  describe 'an attack missing', ->
    it 'deals no damage', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Magikarp')]
      shared.biasRNG.call(this, 'randInt', 'miss', 100)
      move = @battle.getMove('Leaf Storm')
      originalHP = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Leaf Storm'))
      @p2.currentHP.should.equal(originalHP)

    it 'triggers effects dependent on the move missing', ->
      shared.create.call this,
        team1: [Factory('Hitmonlee')]
        team2: [Factory('Magikarp')]
      shared.biasRNG.call(this, 'randInt', 'miss', 100)
      hiJumpKick = @battle.getMove('Hi Jump Kick')
      mock = @sandbox.mock(hiJumpKick).expects('afterMiss').once()
      @battle.performMove(@p1, hiJumpKick)
      mock.verify()

    it 'does not trigger effects dependent on the move hitting', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      shared.biasRNG.call(this, 'randInt', 'miss', 100)
      hiJumpKick = @battle.getMove('Hi Jump Kick')
      mock = @sandbox.mock(hiJumpKick).expects('afterSuccessfulHit').never()
      @battle.performMove(@p1, hiJumpKick)
      mock.verify()

  describe 'fainting', ->
    it 'forces a new pokemon to be picked', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      spy = @sandbox.spy(@battle, 'tellPlayer')
      @p2.currentHP = 1
      @controller.makeMove(@id1, 'Psychic')
      @controller.makeMove(@id2, 'Mach Punch')
      spy.calledWith(@id2, Protocol.REQUEST_ACTIONS).should.be.true

    it 'does not increment the turn count', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      turn = @battle.turn
      @p2.currentHP = 1
      @controller.makeMove(@id1, 'Psychic')
      @controller.makeMove(@id2, 'Mach Punch')
      @battle.turn.should.not.equal turn + 1

    it 'removes the fainted pokemon from the action priority queue', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @p1.currentHP = 1
      @p2.currentHP = 1
      @controller.makeMove(@id1, 'Psychic')
      @controller.makeMove(@id2, 'Mach Punch')
      @p1.currentHP.should.be.below 1
      @p2.currentHP.should.equal 1
      action = @battle.getAction(@p1)
      should.not.exist(action)

    it 'lets the player switch in a new pokemon', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @p2.currentHP = 1
      @controller.makeMove(@id1, 'Psychic')
      @controller.makeMove(@id2, 'Mach Punch')
      @controller.makeSwitch(@id2, 1)
      @team2.first().name.should.equal 'Heracross'

    it "occurs when a pokemon faints from passive damage", ->
      shared.create.call(this)
      @p2.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Leech Seed"))
      spy = @sandbox.spy(@p2, 'faint')
      @battle.endTurn()
      spy.calledOnce.should.be.true

    it "occurs when a pokemon faints normally", ->
      shared.create.call(this)
      @p2.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Tackle"))
      spy = @sandbox.spy(@p2, 'faint')
      @battle.endTurn()
      spy.calledOnce.should.be.true

    it "occurs once for each pokemon", ->
      shared.create.call(this, team2: (Factory("Magikarp")  for x in [1..2]))
      spy = @sandbox.spy(@team2.at(1), 'faint')
      @team2.at(1).currentHP = 1
      @controller.makeMove(@id1, "Tackle")
      @controller.makeSwitch(@id2, 1)
      spy.calledOnce.should.be.true

  describe 'secondary effect attacks', ->
    it 'can inflict effect on successful hit', ->
      shared.create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Porygon-Z')]
      shared.biasRNG.call(this, "next", 'secondary effect', 0)  # 100% chance
      @battle.performMove(@p1, @battle.getMove('Flamethrower'))
      @p2.has(Status.Burn).should.be.true

  describe 'the fang attacks', ->
    it 'can inflict two effects at the same time', ->
      shared.create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Gyarados')]
      shared.biasRNG.call(this, "randInt", "secondary effect", 0)  # 100% chance
      shared.biasRNG.call(this, "randInt", "flinch", 0)
      @battle.performMove(@p1, @battle.getMove("Ice Fang"))

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
      @battle.determineTurnOrder().map((o) -> o.pokemon).should.eql [ @p2, @p1 ]

      @battle.pokemonActions = []

      shared.biasRNG.call(this, "next", "turn order", .4)
      @battle.recordMove(@id1, @battle.getMove('Psychic'))
      @battle.recordMove(@id2, @battle.getMove('Psychic'))
      @battle.determineTurnOrder().map((o) -> o.pokemon).should.eql [ @p1, @p2 ]

    it 'decides winner by highest priority move', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Hitmonchan')]
      spy = @sandbox.spy(@battle, 'determineTurnOrder')
      @battle.recordMove(@id1, @battle.getMove('Mach Punch'))
      @battle.recordMove(@id2, @battle.getMove('Psychic'))
      @battle.determineTurnOrder().map((o) -> o.pokemon).should.eql [ @p1, @p2 ]

      @battle.pokemonActions = []

      @battle.recordMove(@id1, @battle.getMove('Psychic'))
      @battle.recordMove(@id2, @battle.getMove('Mach Punch'))
      @battle.determineTurnOrder().map((o) -> o.pokemon).should.eql [ @p2, @p1 ]

    it 'decides winner by speed if priority is equal', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Hitmonchan', evs: { speed: 4 })]
      @battle.recordMove(@id1, @battle.getMove('ThunderPunch'))
      @battle.recordMove(@id2, @battle.getMove('ThunderPunch'))
      @battle.determineTurnOrder().map((o) -> o.pokemon).should.eql [ @p2, @p1 ]

  describe 'fainting all the opposing pokemon', ->
    it "doesn't request any more actions from players", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @p2.currentHP = 1
      @controller.makeMove(@id1, 'Mach Punch')
      @controller.makeMove(@id2, 'Psychic')
      @battle.requests.should.not.have.property @id1.id
      @battle.requests.should.not.have.property @id2.id

    it 'ends the battle', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @p2.currentHP = 1
      mock = @sandbox.mock(@battle)
      mock.expects('endBattle').once()
      @controller.makeMove(@id1, 'Mach Punch')
      @controller.makeMove(@id2, 'Psychic')
      mock.verify()

  describe 'a pokemon with a type immunity', ->
    it 'cannot be damaged by a move of that type', ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Gyarados')]
      @controller.makeMove(@id1, 'Earthquake')
      @controller.makeMove(@id2, 'Dragon Dance')

      @p2.currentHP.should.equal @p2.stat('hp')

  describe 'a confused pokemon', ->
    it "has a 50% chance of hurting itself", ->
      shared.create.call(this)

      shared.biasRNG.call(this, "randInt", 'confusion turns', 1)  # always 1 turn
      @p1.attach(Attachment.Confusion, {@battle})
      shared.biasRNG.call(this, "next", 'confusion', 0)  # always hits

      mock = @sandbox.mock(@battle.getMove('Tackle'))
      mock.expects('execute').never()

      @controller.makeMove(@id1, 'Tackle')
      @controller.makeMove(@id2, 'Splash')

      mock.verify()

      @p1.currentHP.should.be.lessThan @p1.stat('hp')
      @p2.currentHP.should.equal @p2.stat('hp')

    it "deals a minimum of 1 damage", ->
      shared.create.call(this, team1: [Factory("Shuckle", level: 1)])

      shared.biasRNG.call(this, "randInt", 'confusion turns', 1)  # always 1 turn
      @p1.attach(Attachment.Confusion, {@battle})
      shared.biasRNG.call(this, "next", 'confusion', 0)  # always hits
      @sandbox.stub(@battle.confusionMove, 'calculateDamage', -> 0)

      @battle.performMove(@p1, @battle.getMove('Tackle'))

      @p1.currentHP.should.equal(@p1.stat('hp') - 1)

    it "snaps out of confusion after a predetermined number of turns", ->
      shared.create.call(this)

      shared.biasRNG.call(this, "randInt", 'confusion turns', 1)  # always 1 turn
      @p1.attach(Attachment.Confusion)

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.has(Attachment.Confusion).should.be.false

    it "will not crit the confusion recoil", ->
      shared.create.call(this)

      @p1.attach(Attachment.Confusion)
      shared.biasRNG.call(this, "next", 'confusion', 0)  # always recoils
      shared.biasRNG.call(this, 'next', 'ch', 0) # always crits

      spy = @sandbox.spy(@battle.confusionMove, 'isCriticalHit')
      @controller.makeMove(@id1, 'Tackle')
      @controller.makeMove(@id2, 'Tackle')

      spy.returned(false).should.be.true

    it "will not error for not having unusual move properties", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Iron Fist")])

      @p1.attach(Attachment.Confusion)
      shared.biasRNG.call(this, "next", 'confusion', 0)  # always recoils

      (=>
        @controller.makeMove(@id1, 'Tackle')
        @controller.makeMove(@id2, 'Tackle')
      ).should.not.throw()

  describe 'a frozen pokemon', ->
    it "will not execute moves", ->
      shared.create.call(this)
      @p1.attach(Status.Freeze)
      shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen

      mock = @sandbox.mock(@battle.getMove('Tackle'))
      mock.expects('execute').never()

      @controller.makeMove(@id1, 'Tackle')
      @controller.makeMove(@id2, 'Splash')

      mock.verify()

    it "has a 20% chance of unfreezing", ->
      shared.create.call(this)
      @p1.attach(Status.Freeze)
      shared.biasRNG.call(this, "next", 'unfreeze chance', 0)  # always unfreezes

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.has(Status.Freeze).should.be.false

    it "unfreezes if hit by a fire move", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen
      @p1.attach(Status.Freeze)

      @battle.performMove(@p2, @battle.getMove('Flamethrower'))
      @p1.has(Status.Freeze).should.be.false

    it "does not unfreeze if hit by a non-damaging move", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen
      @p1.attach(Status.Freeze)

      @battle.performMove(@p2, @battle.getMove('Will-O-Wisp'))
      @p1.has(Status.Freeze).should.be.true

    for moveName in ["Sacred Fire", "Flare Blitz", "Flame Wheel", "Fusion Flare", "Scald"]
      it "automatically unfreezes if using #{moveName}", ->
        shared.create.call(this)

        @p1.attach(Status.Freeze)
        shared.biasRNG.call(this, "next", 'unfreeze chance', 1)  # always stays frozen

        @battle.performMove(@p1, @battle.getMove(moveName))
        @p1.has(Status.Freeze).should.be.false

  describe "a paralyzed pokemon", ->
    it "has a 25% chance of being fully paralyzed", ->
      shared.create.call(this)

      @p1.attach(Status.Paralyze)
      shared.biasRNG.call(this, "next", 'paralyze chance', 0)  # always stays frozen

      mock = @sandbox.mock(@battle.getMove('Tackle'))
      mock.expects('execute').never()

      @controller.makeMove(@id1, 'Tackle')
      @controller.makeMove(@id2, 'Splash')

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

    it "loses 1 minimum HP", ->
      shared.create.call(this, team1: [Factory("Shedinja")])
      @p1.attach(Status.Burn)
      @p1.currentHP.should.equal(1)

      @battle.endTurn()
      @p1.currentHP.should.equal(0)

  describe "a sleeping pokemon", ->
    it "sleeps for 1-3 turns", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "randInt", 'sleep turns', 3)
      @p1.attach(Status.Sleep)
      tackle = @battle.getMove('Tackle')

      for i in [0...3]
        @battle.performMove(@p1, tackle)
        @p1.has(Status.Sleep).should.be.true

      @battle.performMove(@p1, tackle)
      @p1.has(Status.Sleep).should.be.false

    it "cannot move while asleep", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "randInt", 'sleep turns', 3)
      @p1.attach(Status.Sleep)
      tackle = @battle.getMove('Tackle')

      mock = @sandbox.mock(tackle).expects('execute').never()
      for i in [0...3]
        @battle.performMove(@p1, tackle)
      mock.verify()
      tackle.execute.restore()

      mock = @sandbox.mock(tackle).expects('execute').once()
      @battle.performMove(@p1, tackle)
      mock.verify()

    it "resets its counter when switching out", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      shared.biasRNG.call(this, "randInt", 'sleep turns', 1)
      @p1.attach(Status.Sleep)
      tackle = @battle.getMove('Tackle')

      @battle.performMove(@p1, tackle)
      @battle.performSwitch(@team1.first(), 1)
      @battle.performSwitch(@team1.first(), 1)
      @battle.performMove(@team1.first(), tackle)
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

    it "loses 1 minimum HP", ->
      shared.create.call(this, team1: [Factory("Shedinja")])
      @p1.attach(Status.Poison)
      @p1.currentHP.should.equal(1)

      @battle.endTurn()
      @p1.currentHP.should.equal(0)

  describe "a badly poisoned pokemon", ->
    it "loses 1/16 of its HP the first turn", ->
      shared.create.call(this)
      @p1.attach(Status.Toxic)
      hp = @p1.currentHP

      @battle.endTurn()
      (hp - @p1.currentHP).should.equal(hp >> 4)

    it "loses 1/16 of its max HP, rounded down, times x where x is the number of turns up to 15", ->
      shared.create.call(this)
      @p1.attach(Status.Toxic)
      hp = @p1.currentHP
      fraction = (hp >> 4)

      for i in [1..16]
        @battle.endTurn()
        hpFraction = Math.min(fraction * i, fraction * 15)
        (hp - @p1.currentHP).should.equal(hpFraction)
        @p1.currentHP = hp

    it "still increases the counter with poison heal", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Poison Heal")])
      @p1.attach(Status.Toxic)
      hp = @p1.currentHP
      fraction = (hp >> 4)
      turns = 3

      for i in [1...turns]
        @battle.endTurn()

      @p1.copyAbility(null)
      @battle.endTurn()
      hpFraction = Math.min(fraction * turns, fraction * 15)
      (hp - @p1.currentHP).should.equal(hpFraction)

    it "loses 1 minimum HP", ->
      shared.create.call(this, team1: [Factory("Shedinja")])
      @p1.attach(Status.Toxic)
      @p1.currentHP.should.equal(1)

      @battle.endTurn()
      @p1.currentHP.should.equal(0)

    it "resets its counter when switching out", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      @p1.attach(Status.Toxic)
      hp = @p1.currentHP

      @battle.endTurn()
      @battle.performSwitch(@team1.first(), 1)
      @p1.currentHP = hp
      @battle.performSwitch(@team1.first(), 1)
      @battle.endTurn()
      (hp - @p1.currentHP).should.equal(hp >> 4)

  describe "Pokemon#turnsActive", ->
    it "is 1 on start of battle", ->
      shared.create.call(this)
      @p1.turnsActive.should.equal 1

    it "is set to 0 when switching", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [1..2]))
      @p1.turnsActive = 4
      @team1.switch(@p1, 0)
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
      @battle.performMove(@p1, move)

  describe "A pokemon with no available moves", ->
    it "can struggle", ->
      shared.create.call(this)
      @battle.removeRequest(@id1)

      # Next turn, @p1 will have no available moves.
      for move in @p1.moves
        @p1.blockMove(move)
      @p1.resetBlocks = ->

      @p1.validMoves().should.be.empty
      @battle.beginTurn()
      request = @battle.requestFor(@p1)
      should.exist(request)
      request.should.have.property('moves')
      request.moves.should.eql(["Struggle"])
