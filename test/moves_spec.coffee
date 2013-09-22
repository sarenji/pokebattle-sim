{Battle, Move, Pokemon, Status, Attachment, Weather} = require('../').server
{Factory} = require './factory'
shared = require('./shared')
should = require('should')
require './helpers'

describe 'Move:', ->
  it 'takes the name as the first parameter', ->
    new Move('Smooth Move').name.should.equal 'Smooth Move'

  it 'should have a priority of 0 by default', ->
    new Move().priority.should.equal 0

  it 'can change the default priority', ->
    new Move(null, priority: -1).priority.should.equal -1

  it 'should have a type of ??? by default', ->
    new Move().type.should.equal '???'

  it 'can change the default type', ->
    new Move(null, type: 'Grass').type.should.equal 'Grass'

  describe 'critical hit level', ->
    it "is 1 by default", ->
      battle = new Battle('1', players: [])
      attacker = new Pokemon()
      defender = new Pokemon()
      attacker.switchIn()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 1

    it "can be changed from the default", ->
      battle = new Battle('1', players: [])
      attacker = new Pokemon()
      defender = new Pokemon()
      attacker.switchIn()
      new Move(null, criticalHitLevel: 2)
        .criticalHitLevel(battle, attacker, defender).should.equal 2

    it "is 3 if the attacker has Focus Energy", ->
      battle = new Battle('1', players: [])
      attacker = new Pokemon()
      defender = new Pokemon()
      attacker.attach(Attachment.FocusEnergy)
      attacker.switchIn()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 3

    it "is 3 if the attacker is Farfetch'd with a Stick", ->
      battle = new Battle('1', players: [])
      attacker = new Pokemon(name: "Farfetch'd", item: 'Stick')
      defender = new Pokemon()
      attacker.switchIn()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 3

    it "is 3 if the attacker is Chansey with a Lucky Punch", ->
      battle = new Battle('1', players: [])
      attacker = new Pokemon(name: "Chansey", item: 'Lucky Punch')
      defender = new Pokemon()
      attacker.switchIn()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 3

    for item in ["Razor Claw", "Scope Lens"]
      do (item) ->
        it "is 2 if the attacker has a #{item}", ->
          battle = new Battle('1', players: [])
          attacker = new Pokemon(item: item)
          defender = new Pokemon()
          attacker.switchIn()
          new Move().criticalHitLevel(battle, attacker, defender).should.equal 2

  describe "a critical hit", ->
    it "occurs when the RNG output < the critical hit level", ->
      battle = new Battle('1', players: [])
      attacker = new Pokemon()
      defender = new Pokemon()
      move = new Move()
      @sandbox.stub(move, 'criticalHitLevel', -> 3)
      @sandbox.stub(battle.rng, 'next', -> 0.2)
      move.isCriticalHit(battle, attacker, defender).should.be.true

    it "does not occur when the RNG output >= the critical hit level", ->
      battle = new Battle('1', players: [])
      attacker = new Pokemon()
      defender = new Pokemon()
      @sandbox.stub(battle.rng, 'next', -> 0.0700)
      new Move().isCriticalHit(battle, attacker, defender).should.be.false

    it "ignores opponent defensive boosts", ->
      shared.create.call(this)
      defense = @p2.stat('defense')
      specialDefense = @p2.stat('specialDefense')

      @p1.crit = true
      @p2.boost(defense: 1, specialDefense: 2)
      move = new Move(null, damage: 'physical')
      move.pickDefenseStat(@p1, @p2).should.equal(defense)
      move = new Move(null, damage: 'special')
      move.pickDefenseStat(@p1, @p2).should.equal(specialDefense)

    it "does not ignore opponent defensive drops", ->
      shared.create.call(this)
      defense = @p2.stat('defense')
      specialDefense = @p2.stat('specialDefense')

      @p1.crit = true
      @p2.boost(defense: -1, specialDefense: -2)
      move = new Move(null, damage: 'physical')
      move.pickDefenseStat(@p1, @p2).should.equal Math.floor(2 / 3 * defense)
      move = new Move(null, damage: 'special')
      move.pickDefenseStat(@p1, @p2).should.equal(specialDefense >> 1)

    it "ignores user stat drops", ->
      shared.create.call(this)
      attack = @p1.stat('attack')
      specialAttack = @p1.stat('specialAttack')

      @p1.crit = true
      @p1.boost(attack: -1, specialAttack: -2)
      move = new Move(null, damage: 'physical')
      move.pickAttackStat(@p1, @p2).should.equal(attack)
      move = new Move(null, damage: 'special')
      move.pickAttackStat(@p1, @p2).should.equal(specialAttack)

    it "does not ignore user stat boosts", ->
      shared.create.call(this)
      attack = @p1.stat('attack')
      specialAttack = @p1.stat('specialAttack')

      @p1.crit = true
      @p1.boost(attack: 1, specialAttack: 2)
      move = new Move(null, damage: 'physical')
      move.pickAttackStat(@p1, @p2).should.equal Math.floor(1.5 * attack)
      move = new Move(null, damage: 'special')
      move.pickAttackStat(@p1, @p2).should.equal(2 * specialAttack)

    it "does not carry over in multihit moves", ->
      shared.create.call(this)
      move = new Move("multihit", minHits: 4, maxHits: 4, power: 20)

      # Crit only once
      move.isCriticalHit = ->
        move.isCriticalHit = -> false
        true

      mock = @sandbox.mock(@p2).expects('informCriticalHit').once()
      move.execute(@battle, @p1, [ @p2 ])
      mock.verify()

    describe "-1 crit ratios", ->
      beforeEach ->
        @battle = new Battle('1', players: [])
        @attacker = new Pokemon()
        @move = new Move("TestMove", criticalHitLevel: -1)
        @sandbox.stub(@battle.rng, 'next', -> 1)

      it "fails if the defender has Battle Armor", ->
        defender = new Pokemon(ability: 'Battle Armor')
        @move.isCriticalHit(@battle, @attacker, defender).should.be.false

      it "fails if the defender has Shell Armor", ->
        defender = new Pokemon(ability: 'Shell Armor')
        @move.isCriticalHit(@battle, @attacker, defender).should.be.false

      it "always succeeds if opponent does not have Battle or Shell Armor", ->
        defender = new Pokemon()
        @move.isCriticalHit(@battle, @attacker, defender).should.be.true

  describe 'type effectiveness', ->
    testTypeEffectiveness = (type, defense, expected) ->
      battle = new Battle('1', players: [])
      attacker = new Pokemon()
      defender = new Pokemon()
      defender.types = defense
      move = new Move(null, type: type)
      move.typeEffectiveness(battle, attacker, defender).should.equal expected

    it 'is 0 if the enemy has an immunity to the type', ->
      testTypeEffectiveness('Ground', ['Electric', 'Flying'], 0)

    it 'is 1 if the enemy is neutral to the type', ->
      testTypeEffectiveness('Ground', ['Normal'], 1)

    it 'is 2 if the enemy is weak to the type', ->
      testTypeEffectiveness('Ground', ['Electric'], 2)

    it 'is 4 if the enemy is extra weak to the type', ->
      testTypeEffectiveness('Rock', ['Fire', 'Flying'], 4)

    it 'is 1/2 if the enemy is resistant to the type', ->
      testTypeEffectiveness('Fire', ['Fire', 'Flying'], .5)

    it 'is 1/4 if the enemy is extra resistant to the type', ->
      testTypeEffectiveness('Fire', ['Fire', 'Water'], .25)

  describe "#burnCalculation", ->
    it "returns 1 normally", ->
      attacker = new Pokemon()
      new Move(null, damage: 'physical')
        .burnCalculation(attacker).should.equal 1

    it "returns .5 with a physical move, no Guts ability, and a burned user", ->
      attacker = new Pokemon()
      attacker.attach(Status.Burn)
      new Move(null, damage: 'physical')
        .burnCalculation(attacker).should.equal .5

    it "returns 1 with a special move, no Guts ability, and a burned user", ->
      attacker = new Pokemon()
      attacker.attach(Status.Burn)
      new Move(null, damage: 'special')
        .burnCalculation(attacker).should.equal 1

    it "returns 1 with a physical move, Guts ability, and a burned user", ->
      attacker = new Pokemon(ability: "Guts")
      attacker.attach(Status.Burn)
      new Move(null, damage: 'physical')
        .burnCalculation(attacker).should.equal 1

  describe 'an attack with 0 accuracy', ->
    it 'can never miss', ->
      battle = new Battle('1', players: [])
      a = new Pokemon()
      d = new Pokemon()
      new Move(accuracy: 0).willMiss(battle, a, d).should.be.false

  describe 'accuracy and evasion boosts', ->
    it 'heighten and lower the chances of a move hitting', ->
      battle = new Battle('1', players: [])
      a = new Pokemon()
      d = new Pokemon()
      new Move(null, accuracy: 100).chanceToHit(battle, a, d).should.eql 100

      a.stages.accuracy = 3
      new Move(null, accuracy: 50).chanceToHit(battle, a, d).should.eql 100

      a.stages.accuracy = 3
      d.stages.evasion = 3
      new Move(null, accuracy: 50).chanceToHit(battle, a, d).should.eql 50

  describe '#hasFlag', ->
    it 'returns true if a move has a specific flag', ->
      new Move(null, flags: ['superman', 'batman'])
        .hasFlag('batman').should.be.true

    it "returns false if a move doesn't have a specific flag", ->
      new Move(null, flags: ['superman', 'batman'])
        .hasFlag('catwoman').should.be.false

  describe '#execute', ->
    it 'calls use multiple times for multihit moves', ->
      shared.create.call(this)
      move = new Move("multihit", minHits: 4, maxHits: 4)
      mock = @sandbox.mock(move).expects('use').exactly(4)

      move.execute(@battle, @p1, [@p2], true)
      mock.verify()

  describe "#use", ->
    it "returns false if the target's type is immune", ->
      shared.create.call(this)
      move = new Move("attacking", damage: "special", type: "Normal")
      @p2.types = [ "Ghost" ]
      move.use(@battle, @p1, @p2).should.be.false

    it "returns true if target is immune but move is non-damaging", ->
      shared.create.call(this)
      move = new Move("attacking", damage: "non-damaging", type: "Normal")
      @p2.types = [ "Ghost" ]
      should.not.exist move.use(@battle, @p1, @p2)

  describe '#hit', ->
    it "deals damage no higher than the pokemon's remaining HP", ->
      shared.create.call(this)
      mock = @sandbox.mock(@p2).expects('damage').withArgs(1)

      @p2.currentHP = 1
      @battle.performMove(@id1, @battle.getMove("Tackle"))
      mock.verify()

    it "deals normal damage if the Pokemon has a substitute", ->
      shared.create.call(this)
      spy = @sandbox.spy(@p2, 'damage')

      @p2.currentHP = (@p2.currentHP >> 2) + 1
      @battle.performMove(@id2, @battle.getMove("Substitute"))
      @battle.performMove(@id1, @battle.getMove("Tackle"))
      spy.returned(1).should.be.false

  describe '#weatherModifier', ->
    it "is 0x1800 when the move is Fire-type and the weather is sunny", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SUN)
      move = new Move(null, type: "Fire")
      move.weatherModifier(@battle, @p1, @p2).should.equal(0x1800)

    it "is 0x800 when the move is Fire-type and the weather is rainy", ->
      shared.create.call(this)
      @battle.setWeather(Weather.RAIN)
      move = new Move(null, type: "Fire")
      move.weatherModifier(@battle, @p1, @p2).should.equal(0x800)

    it "is 0x1800 when the move is Water-type and the weather is rainy", ->
      shared.create.call(this)
      @battle.setWeather(Weather.RAIN)
      move = new Move(null, type: "Water")
      move.weatherModifier(@battle, @p1, @p2).should.equal(0x1800)

    it "is 0x1800 when the move is Water-type and the weather is sunny", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SUN)
      move = new Move(null, type: "Water")
      move.weatherModifier(@battle, @p1, @p2).should.equal(0x800)

    it "is 0x1000 otherwise", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SAND)
      move = new Move(null, type: "Fire")
      move.weatherModifier(@battle, @p1, @p2).should.equal(0x1000)
