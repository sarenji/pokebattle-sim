require '../helpers'

{Attachment, Status} = require('../../server/bw/attachment')
{Battle} = require('../../server/bw/battle')
{Pokemon} = require('../../server/bw/pokemon')
{Weather} = require('../../shared/weather')
{Move} = require('../../server/bw/move')
util = require '../../server/bw/util'
{Protocol} = require '../../shared/protocol'
{Factory} = require '../factory'
should = require 'should'
{_} = require 'underscore'
shared = require '../shared'

describe 'Move:', ->
  # Test every single move for their primary effects.
  shared.testEveryMove(Battle::MoveList, 'bw')

  it "multiplies critical hits by 2x", ->
    Move::criticalMultiplier.should.equal(2)

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
      battle = new Battle('1', [])
      attacker = new Pokemon()
      defender = new Pokemon()
      attacker.activate()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 1

    it "can be changed from the default", ->
      battle = new Battle('1', [])
      attacker = new Pokemon()
      defender = new Pokemon()
      attacker.activate()
      new Move(null, criticalHitLevel: 2)
        .criticalHitLevel(battle, attacker, defender).should.equal 2

    it "is 3 if the attacker has Focus Energy", ->
      battle = new Battle('1', [])
      attacker = new Pokemon()
      defender = new Pokemon()
      attacker.attach(Attachment.FocusEnergy)
      attacker.activate()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 3

    it "is 3 if the attacker is Farfetch'd with a Stick", ->
      battle = new Battle('1', [])
      attacker = new Pokemon(species: "Farfetch'd", item: 'Stick')
      defender = new Pokemon()
      attacker.activate()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 3

    it "is 3 if the attacker is Chansey with a Lucky Punch", ->
      battle = new Battle('1', [])
      attacker = new Pokemon(species: "Chansey", item: 'Lucky Punch')
      defender = new Pokemon()
      attacker.activate()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 3

    for item in ["Razor Claw", "Scope Lens"]
      do (item) ->
        it "is 2 if the attacker has a #{item}", ->
          battle = new Battle('1', [])
          attacker = new Pokemon(item: item)
          defender = new Pokemon()
          attacker.activate()
          new Move().criticalHitLevel(battle, attacker, defender).should.equal 2

  describe "a critical hit", ->
    it "occurs when the RNG output < the critical hit level", ->
      battle = new Battle('1', [])
      attacker = new Pokemon()
      defender = new Pokemon()
      move = new Move()
      @sandbox.stub(move, 'criticalHitLevel', -> 3)
      @sandbox.stub(battle.rng, 'next', -> 0.2)
      move.isCriticalHit(battle, attacker, defender).should.be.true

    it "does not occur when the RNG output >= the critical hit level", ->
      battle = new Battle('1', [])
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
        @battle = new Battle('1', [])
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
      battle = new Battle('1', [])
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
      battle = new Battle('1', [])
      a = new Pokemon()
      d = new Pokemon()
      new Move(accuracy: 0).willMiss(battle, a, d).should.be.false

  describe 'accuracy and evasion boosts', ->
    it 'heighten and lower the chances of a move hitting', ->
      battle = new Battle('1', [])
      a = new Pokemon()
      d = new Pokemon()
      new Move(null, accuracy: 100).chanceToHit(battle, a, d).should.eql 100

      a.stages.accuracy = 3
      new Move(null, accuracy: 50).chanceToHit(battle, a, d).should.eql 100

      a.stages.accuracy = 3
      d.stages.evasion = 3
      new Move(null, accuracy: 50).chanceToHit(battle, a, d).should.eql 50

    it 'keeps heightening and lowering chances when negative', ->
      battle = new Battle('1', [])
      a = new Pokemon()
      d = new Pokemon()
      new Move(null, accuracy: 100).chanceToHit(battle, a, d).should.eql 100

      a.stages.accuracy = -3
      new Move(null, accuracy: 50).chanceToHit(battle, a, d).should.eql 25

      a.stages.accuracy = -3
      d.stages.evasion = -3
      new Move(null, accuracy: 50).chanceToHit(battle, a, d).should.eql 50

  describe '#hasFlag', ->
    it 'returns true if a move has a specific flag', ->
      new Move(null, flags: ['superman', 'batman'])
        .hasFlag('batman').should.be.true

    it "returns false if a move doesn't have a specific flag", ->
      new Move(null, flags: ['superman', 'batman'])
        .hasFlag('catwoman').should.be.false

  describe '#execute', ->
    it 'calls hit multiple times for multihit moves', ->
      shared.create.call(this)
      move = new Move("multihit", minHits: 4, maxHits: 4)
      mock = @sandbox.mock(move).expects('hit').exactly(4)

      move.execute(@battle, @p1, [@p2])
      mock.verify()

    it 'only hits up until user faints', ->
      shared.create.call(this, team2: [Factory('Ferrothorn', ability: 'Iron Barbs')])
      move = new Move("multihit", minHits: 4, maxHits: 4, flags: ["contact"])
      mock = @sandbox.mock(move).expects('hit').exactly(1)

      @p1.currentHP = 1
      move.execute(@battle, @p1, [@p2])
      mock.verify()

    it 'only hits up until user falls asleep', ->
      shared.create.call(this, team2: [Factory('Shroomish', ability: 'Effect Spore')])
      shared.biasRNG.call(this, "randInt", 'effect spore', 4)  # Never trigger
      move = new Move("multihit", minHits: 4, maxHits: 4, flags: ["contact"])

      hit = move.hit
      times = 0
      @sandbox.stub move, 'hit', =>
        times++
        if times == 2
          shared.biasRNG.call(this, "randInt", 'effect spore', 1)  # Sleep
        else
          shared.biasRNG.call(this, "randInt", 'effect spore', 4)  # Nothing
        hit.apply(move, arguments)

      @p1.currentHP = 1
      move.execute(@battle, @p1, [@p2])
      times.should.equal(2)

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
      @p2.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Tackle"))
      @p2.currentHP.should.equal(0)

    it "deals normal damage if the Pokemon has a substitute", ->
      shared.create.call(this)
      spy = @sandbox.spy(@p2, 'damage')

      @p2.currentHP = (@p2.currentHP >> 2) + 1
      @battle.performMove(@p2, @battle.getMove("Substitute"))
      @battle.performMove(@p1, @battle.getMove("Tackle"))
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

  describe "#baseDamage", ->
    it "reduces damage by ~1.5 if the weather is sandstorm", ->
      shared.create.call(this)
      @p2.types = [ "Rock" ]
      move = new Move(null, power: 50, type: "Fire", damage: 'special')
      damage = move.baseDamage(@battle, @p1, @p2)
      @battle.setWeather(Weather.SAND)
      move.baseDamage(@battle, @p1, @p2).should.be.lessThan(damage)

    it "doesn't apply the sandstorm effect if target isn't Rock-type", ->
      shared.create.call(this)
      @p2.types = [ "Ground" ]
      move = new Move(null, power: 50, type: "Fire", damage: 'special')
      damage = move.baseDamage(@battle, @p1, @p2)
      @battle.setWeather(Weather.SAND)
      move.baseDamage(@battle, @p1, @p2).should.equal(damage)

    it "doesn't apply the sandstorm effect if move is non-special", ->
      shared.create.call(this)
      @p2.types = [ "Rock" ]
      move = new Move(null, power: 50, type: "Fire", damage: 'physical')
      damage = move.baseDamage(@battle, @p1, @p2)
      @battle.setWeather(Weather.SAND)
      move.baseDamage(@battle, @p1, @p2).should.equal(damage)

describe "BW Moves:", ->
  describe "Splash", ->
    shared.shouldDoNoDamage('Splash')

  describe 'a multi-hit move', ->
    it 'potentially activates Berries after each hit', ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: "Sitrus Berry", ability: "Skill Link")]
        team2: [Factory('Magikarp', item: "Sitrus Berry", ability: "Iron Barbs")]
      hp = @p1.currentHP
      @p1.currentHP = (hp >> 1) + 1
      @p2.currentHP = 4
      move = @battle.getMove('Tail Slap')
      @sandbox.stub(move, 'calculateDamage', -> 1)
      @battle.performMove(@p1, move)
      @p1.currentHP.should.equal (hp >> 1) + 1 - (5 * (hp >> 3)) + (hp >> 2)
      @p2.currentHP.should.equal 4 + (hp >> 2) - 5

  describe 'jump kick attacks', ->
    it 'has 50% recoil if it misses', ->
      shared.create.call(this)
      shared.biasRNG.call(this, "randInt", 'miss', 100)
      oldHP = @p1.stat('hp')
      @battle.performMove(@p1, @battle.getMove('Hi Jump Kick'))
      (oldHP - @p1.currentHP).should.equal Math.floor(oldHP / 2)

    it "has 50% recoil if the target is immune", ->
      shared.create.call(this, team2: [Factory("Gengar")])
      oldHP = @p1.stat('hp')
      @battle.performMove(@p1, @battle.getMove('Hi Jump Kick'))
      (oldHP - @p1.currentHP).should.equal Math.floor(oldHP / 2)

    it "has 50% recoil if the target protects itself", ->
      shared.create.call(this)
      oldHP = @p1.stat('hp')
      @battle.recordMove(@id2, @battle.getMove("Protect"))
      @battle.recordMove(@id1, @battle.getMove("Hi Jump Kick"))
      @battle.continueTurn()
      (oldHP - @p1.currentHP).should.equal Math.floor(oldHP / 2)

  describe 'a drain attack', ->
    it 'recovers a percentage of the damage dealt, rounded down', ->
      shared.create.call this,
        team1: [Factory('Conkeldurr')]
        team2: [Factory('Hitmonchan')]
      startHP = 1
      @p1.currentHP = startHP
      hp = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Drain Punch'))
      damage = (hp - @p2.currentHP)
      (@p1.currentHP - startHP).should.equal Math.ceil(damage / 2)

    it 'cannot recover to over 100% HP', ->
      shared.create.call this,
        team1: [Factory('Conkeldurr')]
        team2: [Factory('Hitmonchan')]
      hp = @p1.currentHP = @p1.stat('hp')
      @battle.performMove(@p1, @battle.getMove('Drain Punch'))
      (@p1.currentHP - hp).should.equal 0

    it "does not recover more than the damage dealt", ->
      shared.create.call(this)
      drainPunch = @battle.getMove('Drain Punch')
      @sandbox.stub(drainPunch, 'baseDamage', -> 9999)
      @p2.currentHP = 2
      @p1.currentHP = 1
      @battle.performMove(@p1, drainPunch)
      @p2.currentHP.should.be.lessThan(1)
      @p1.currentHP.should.equal(2)

  describe 'weight-based attacks', ->
    it 'has 80 base power if the pokemon is 50.2kg', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Hitmonchan')]
      hp = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Grass Knot'))
      (hp - @p2.currentHP).should.equal 94

    it 'has 120 base power if the pokemon is >200kg', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      hp = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Grass Knot'))
      (hp - @p2.currentHP).should.equal 153

  describe 'a pokemon using a primary boosting move', ->
    it "doesn't do damage if base power is 0", ->
      shared.create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Hitmonchan')]
      @battle.performMove(@p1, @battle.getMove('Dragon Dance'))
      @p2.currentHP.should.equal @p2.stat('hp')

    it "boosts the pokemon's stats", ->
      shared.create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Hitmonchan')]
      @battle.performMove(@p1, @battle.getMove('Dragon Dance'))
      @p1.stages.should.containEql attack: 1, speed: 1

    it "affects type-immune pokemon", ->
      shared.create.call this,
        team1: [Factory('Audino')]
        team2: [Factory('Gengar')]
      @battle.performMove(@p1, @battle.getMove('Growl'))
      @p2.stages.attack.should.equal -1

    it "has the boosts removed on switch", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [1..2]))
      @battle.performMove(@p1, @battle.getMove('Dragon Dance'))
      @battle.performSwitch(@p1, 1)
      @p1.stages.should.containEql(attack: 0, speed: 0)

  describe 'a pokemon using a damaging move that also boosts stats on hit', ->
    it "deals damage and boosts stats", ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      hp = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Leaf Storm'))
      @p1.stages.specialAttack.should.equal -2
      (hp - @p2.currentHP).should.equal 178

  describe 'Low Sweep', ->
    it "lowers the target's speed by 1", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove('Low Sweep'))
      @p2.stages.speed.should.equal(-1)

    it "does not lower the target's speed by 1 if the target faints", ->
      shared.create.call(this)
      @p2.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Low Sweep'))
      @p2.stages.speed.should.not.equal(-1)

    it "does not lower the target's speed by 1 if it hits a substitute", ->
      shared.create.call(this)
      @p2.attach(Attachment.Substitute)
      @battle.performMove(@p1, @battle.getMove('Low Sweep'))
      @p2.stages.speed.should.not.equal(-1)

  describe 'Flame Charge', ->
    it "raises the user's speed by 1", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove('Flame Charge'))
      @p1.stages.speed.should.equal(1)

    it "raises the user's speed by 1 even if the target faints", ->
      shared.create.call(this)
      @p2.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Flame Charge'))
      @p1.stages.speed.should.equal(1)

    it "raises the user's speed by 1 even if it hits a substitute", ->
      shared.create.call(this)
      @p2.attach(Attachment.Substitute)
      @battle.performMove(@p1, @battle.getMove('Flame Charge'))
      @p1.stages.speed.should.equal(1)

  describe 'a pokemon using a move with a secondary boosting effect', ->
    it "has a chance to activate", ->
      shared.create.call this,
        team1: [Factory('Mew')]
        team2: [Factory('Hitmonchan')]
      shared.biasRNG.call(this, "next", 'secondary boost', 0)  # 100% chance
      attack = @p1.stat('attack')
      speed  = @p1.stat('speed')
      @battle.performMove(@p1, @battle.getMove('AncientPower'))
      @p1.stages.should.containEql {
        attack: 1, defense: 1, speed: 1, specialAttack: 1, specialDefense: 1
      }

  describe 'a pokemon using Acrobatics', ->
    it 'gets double the base power without an item', ->
      shared.create.call this,
        team1: [Factory('Gliscor')]
        team2: [Factory('Regirock')]
      hp = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Acrobatics'))
      damage = (hp - @p2.currentHP)
      damage.should.equal 36

    it 'has normal base power with an item', ->
      shared.create.call this,
        team1: [Factory('Gliscor', item: 'Leftovers')]
        team2: [Factory('Regirock')]
      hp = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Acrobatics'))
      damage = (hp - @p2.currentHP)
      damage.should.equal 18

  testRecoilMove = (moveName) ->
    describe "a pokemon using #{moveName}", ->
      it 'receives a percentage of the damage rounded half up', ->
        shared.create.call(this)
        startHP = @p1.currentHP
        hp = @p2.currentHP

        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)
        recoil = -move.recoil / 100

        damage = (hp - @p2.currentHP)
        (startHP - @p1.currentHP).should.equal Math.round(damage * recoil)

      it 'receives a minimum of 1 HP of recoil', ->
        shared.create.call(this)
        startHP = @p1.currentHP
        hp = @p2.currentHP

        move = @battle.getMove(moveName)
        stub = @sandbox.stub(move, 'calculateDamage', -> .6)

        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)

        damage = (hp - @p2.currentHP)
        (startHP - @p1.currentHP).should.equal 1

      it "does not recoil if no damage was dealt", ->
        shared.create.call(this)
        @battle.recordMove(@id2, @battle.getMove("Protect"))
        @battle.recordMove(@id1, @battle.getMove(moveName))
        @battle.continueTurn()
        @p1.currentHP.should.equal(@p1.stat('hp'))

  testRecoilMove("Brave Bird")
  testRecoilMove("Double-Edge")
  testRecoilMove("Flare Blitz")
  testRecoilMove("Head Charge")
  testRecoilMove("Head Smash")
  testRecoilMove("Submission")
  testRecoilMove("Take Down")
  testRecoilMove("Volt Tackle")
  testRecoilMove("Wild Charge")
  testRecoilMove("Wood Hammer")

  testDrainMove = (moveName) ->
    describe moveName, ->
      it "absorbs a percentage of the damage rounded up", ->
        shared.create.call(this)
        @p1.currentHP = 1

        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)
        drain = move.recoil / 100

        damage = (@p2.stat('hp') - @p2.currentHP)
        (@p1.currentHP - 1).should.equal Math.ceil(damage * drain)

      it 'receives a minimum of 1 HP of drain', ->
        shared.create.call(this)
        @p1.currentHP = @p2.currentHP = 1

        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)
        @p1.currentHP.should.equal(2)

      it "does not drain if no damage was dealt", ->
        shared.create.call(this)
        @p1.currentHP = 1
        @battle.recordMove(@id2, @battle.getMove("Protect"))
        @battle.recordMove(@id1, @battle.getMove(moveName))
        @battle.continueTurn()
        @p1.currentHP.should.equal(1)

  testDrainMove("Absorb")
  testDrainMove("Drain Punch")
  testDrainMove("Giga Drain")
  testDrainMove("Horn Leech")
  testDrainMove("Leech Life")
  testDrainMove("Mega Drain")

  describe 'Haze', ->
    shared.shouldDoNoDamage('Haze')

    it 'removes all status boosts from each pokemon', ->
      shared.create.call(this)
      # Create artificial boosts.
      @p1.stages.attack = 2
      @p1.stages.evasion = -1
      @p2.stages.defense = -3
      @p2.stages.specialAttack = 4
      @battle.performMove(@p1, @battle.getMove("Haze"))
      neutralBoosts = {
        attack: 0, defense: 0, specialAttack: 0, specialDefense: 0,
        speed: 0, evasion: 0, accuracy: 0
      }
      @p1.stages.should.eql neutralBoosts
      @p2.stages.should.eql neutralBoosts

  describe 'Seismic Toss and Night Shade', ->
    it 'does exactly the same damage as their level', ->
      shared.create.call this,
        team1: [Factory('Blissey')]
        team2: [Factory('Mew')]
      hp = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Seismic Toss'))
      (hp - @p2.currentHP).should.equal 100

  describe 'Psywave', ->
    it 'does user.level/2 damage minimum', ->
      shared.create.call this,
        team1: [Factory('Weezing')]
        team2: [Factory('Mew')]
      shared.biasRNG.call(this, "randInt", 'psywave', 5)
      hp = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Psywave'))
      (hp - @p2.currentHP).should.equal 50

    it 'does user.level * 1.5 damage maximum', ->
      shared.create.call this,
        team1: [Factory('Weezing')]
        team2: [Factory('Mew')]
      move = @battle.getMove('Psywave')
      shared.biasRNG.call(this, "randInt", 'psywave', 15)
      hp = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Psywave'))
      (hp - @p2.currentHP).should.equal 150

    it 'rounds down to the nearest .1 multiplier', ->
      shared.create.call this,
        team1: [Factory('Weezing')]
        team2: [Factory('Mew')]
      move = @battle.getMove('Psywave')
      shared.biasRNG.call(this, "randInt", 'psywave', 6.09)
      hp = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Psywave'))
      (hp - @p2.currentHP).should.equal 60

  describe 'facade', ->
    it 'doubles the base power if burned, poisoned, or paralyzed', ->
      shared.create.call this,
        team1: [Factory('Zangoose')]
        team2: [Factory('Magikarp')]
      hp = @p2.currentHP
      @p1.attach(Status.Paralyze)
      move = @battle.getMove('Facade')
      basePower = move.basePower(@battle, @p1, @p2)
      basePower.should.equal(2 * move.power)

  describe 'reversal and flail', ->
    it 'have 200 base power at 1 hp', ->
      shared.create.call this,
        team1: [Factory('Zangoose')]
        team2: [Factory('Magikarp')]
      @p1.currentHP = 1
      move = @battle.getMove('Flail')
      basePower = move.basePower(@battle, @p1, @p2)
      basePower.should.equal 200

    it 'have 40 base power at 50% hp', ->
      shared.create.call this,
        team1: [Factory('Zangoose')]
        team2: [Factory('Magikarp')]
      @p1.currentHP = Math.floor(@p1.stat('hp') / 2)
      move = @battle.getMove('Flail')
      basePower = move.basePower(@battle, @p1, @p2)
      basePower.should.equal 40

  describe 'eruption and water spout', ->
    beforeEach ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Mew')]
      @attacker = @p1
      @defender = @p2
      @move = @battle.getMove('Eruption')

    it 'has at least one base power', ->
      @attacker.currentHP = 1
      @move.basePower(@battle, @attacker, @defender).should.equal 1

    it 'has 75 base power at 50% hp', ->
      @attacker.currentHP = @attacker.stat('hp') / 2
      @move.basePower(@battle, @attacker, @defender).should.equal 75

    it 'has 150 base power at 100% hp', ->
      @move.basePower(@battle, @attacker, @defender).should.equal 150

  describe 'gyro ball', ->
    it 'has 150 base power maximum', ->
      shared.create.call this,
        team1: [Factory('Forretress', ivs: {speed: 0})]
        team2: [Factory('Jolteon', evs: {speed: 252}, nature: "Timid")]
      move = @battle.getMove('Gyro Ball')
      attacker = @p1
      defender = @p2
      attacker.stages.speed = -6
      move.basePower(@battle, attacker, defender).should.equal 150

    it 'has variable base power based on speed of target and user', ->
      shared.create.call this,
        team1: [Factory('Electrode', evs: {speed: 252}, nature: "Jolly")]
        team2: [Factory('Magikarp', ivs: {speed: 0})]
      move = @battle.getMove('Gyro Ball')
      attacker = @p1
      defender = @p2
      attacker.stages.speed = -6
      move.basePower(@battle, attacker, defender).should.equal 40

  describe 'brine', ->
    it 'has normal base power if the target has over 50% HP', ->
      shared.create.call this,
        team1: [Factory('Empoleon')]
        team2: [Factory('Magikarp')]
      move = @battle.getMove('Brine')
      @p2.currentHP = Math.floor(@p2.currentHP / 2) + 1
      move.basePower(@battle, @p1, @p2).should.equal 65

    it 'doubles base power if the target has 50% or less HP', ->
      shared.create.call this,
        team1: [Factory('Empoleon')]
        team2: [Factory('Magikarp')]
      move = @battle.getMove('Brine')
      @p2.currentHP = Math.floor(@p2.currentHP / 2)
      move.basePower(@battle, @p1, @p2).should.equal 130

  describe 'Disable', ->
    shared.shouldDoNoDamage('Disable')

    it 'gives the disabled attachment', ->
      shared.create.call(this)
      disable = @battle.getMove("Disable")
      move = @p2.moves[0]

      @battle.performMove(@p2, move)
      @battle.performMove(@p1, disable)
      @p2.has(Attachment.Disable).should.be.true

    it "prevents the target's last move from being selected", ->
      shared.create.call(this)
      disable = @battle.getMove("Disable")
      move = @p2.moves[0]

      @battle.performMove(@p2, move)
      @battle.performMove(@p1, disable)
      @battle.beginTurn()

      @p2.validMoves().should.not.containEql(move)
      @p2.validMoves().should.have.length(@p2.moves.length - 1)

    it 'wears off after 4 turns', ->
      shared.create.call(this)
      disable = @battle.getMove("Disable")
      move = @p2.moves[0]

      @battle.performMove(@p2, move)
      @battle.performMove(@p1, disable)

      @battle.endTurn()
      @battle.endTurn()
      @battle.endTurn()
      @battle.endTurn()

      @p2.has(Attachment.Disable).should.be.false

    it 'stops the execution of a disabled move', ->
      shared.create.call(this)
      disable = @battle.getMove("Disable")
      move = @p2.moves[0]

      @battle.performMove(@p2, move)
      @battle.performMove(@p1, disable)
      mock = @sandbox.mock(move).expects('execute').never()
      @battle.performMove(@p2, move)
      mock.verify()

    it 'fails if the target has not moved since it was active', ->
      shared.create.call(this)
      disable = @battle.getMove("Disable")

      mock = @sandbox.mock(disable).expects('fail').once()
      @battle.performMove(@p1, disable)
      mock.verify()

    it 'fails if the target does not know the move it used', ->
      shared.create.call(this)
      disable = @battle.getMove("Disable")
      struggle = @battle.getMove("Struggle")

      mock = @sandbox.mock(disable).expects('fail').once()
      @battle.performMove(@p2, struggle)
      @battle.performMove(@p1, disable)
      mock.verify()

    it "fails if the target's last move has 0 PP", ->
      shared.create.call(this)
      disable = @battle.getMove("Disable")
      splash = @battle.getMove("Splash")

      @battle.performMove(@p2, splash)
      @p2.setPP(splash, 0)
      mock = @sandbox.mock(disable).expects('fail').once()
      @battle.performMove(@p1, disable)
      mock.verify()

  describe 'hidden power', ->
    it 'has a max power of 70', ->
      ivs = {
        hp: 31, attack: 31, defense: 31,
        specialAttack: 31, specialDefense: 31, speed: 31
      }
      shared.create.call this,
        team1: [Factory('Magikarp', ivs: ivs)]
        team2: [Factory('Magikarp')]
      move = @battle.getMove('Hidden Power')
      move.basePower(@battle, @p1, @p2).should.eql 70

    it 'has a min power of 30', ->
      ivs = {
        hp: 0, attack: 0, defense: 0,
        specialAttack: 0, specialDefense: 0, speed: 0
      }
      shared.create.call this,
        team1: [Factory('Magikarp', ivs: ivs)]
        team2: [Factory('Magikarp')]
      move = @battle.getMove('Hidden Power')
      move.basePower(@battle, @p1, @p2).should.eql 30

    it 'is dark when all ivs are 31', ->
      ivs = {
        hp: 31, attack: 31, defense: 31,
        specialAttack: 31, specialDefense: 31, speed: 31
      }
      shared.create.call this,
        team1: [Factory('Magikarp', ivs: ivs)]
        team2: [Factory('Magikarp')]
      move = @battle.getMove('Hidden Power')
      move.getType(@battle, @p1, @p2).should.eql 'Dark'

    it 'is fighting when all ivs are 0', ->
      ivs = {
        hp: 0, attack: 0, defense: 0,
        specialAttack: 0, specialDefense: 0, speed: 0
      }
      shared.create.call this,
        team1: [Factory('Magikarp', ivs: ivs)]
        team2: [Factory('Magikarp')]
      move = @battle.getMove('Hidden Power')
      move.getType(@battle, @p1, @p2).should.eql 'Fighting'

  describe 'yawn', ->
    shared.shouldDoNoDamage('Yawn')
    shared.shouldFailIfUsedTwice("Yawn")

    it 'gives the yawn attachment', ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Magikarp')]
      @battle.performMove(@p1, @battle.getMove('Yawn'))
      @p2.has(Attachment.Yawn).should.be.true

    it 'puts the opponent to sleep at the end of the second turn', ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Magikarp')]
      @battle.performMove(@p1, @battle.getMove('Yawn'))
      @battle.endTurn()
      @p2.has(Status.Sleep).should.be.false
      @battle.endTurn()
      @p2.has(Status.Sleep).should.be.true

    it "fails if the target already is statused", ->
      shared.create.call(this)
      yawn = @battle.getMove('Yawn')
      mock = @sandbox.mock(yawn).expects('fail').once()

      @p2.attach(Status.Paralyze)
      @battle.performMove(@p1, yawn)
      mock.verify()

  describe 'an OHKO move', ->
    it 'ignores accuracy/evasion modifiers', ->
      shared.create.call(this)
      @p1.stages.accuracy = -6
      @p2.stages.evasion = 6
      acc = @battle.getMove('Sheer Cold').chanceToHit(@battle, @p1, @p2)

      acc.should.equal 30

    it "does damage equal to the target's total hp", ->
      shared.create.call this,
        team1: [Factory('Lapras')]
        team2: [Factory('Magikarp')]
      @p2.currentHP = Math.floor(@p2.stat('hp') / 2)
      @controller.makeMove(@id1, 'Sheer Cold')
      @controller.makeMove(@id2, 'Splash')

      move = @battle.getMove('Sheer Cold')
      damage = move.calculateDamage(@battle, @p1, @p2)
      damage.should.equal @p2.stat('hp')

  describe 'a recovery move', ->
    shared.shouldDoNoDamage('Recover')

    it "recovers 50% of the target's HP, rounded half up", ->
      shared.create.call(this)
      hp = @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Softboiled'))

      recoverHP = Math.round(@p1.stat('hp') / 2)
      (@p1.currentHP - hp).should.equal recoverHP

    it "fails if the user's HP is full", ->
      shared.create.call(this)
      softboiled = @battle.getMove('Softboiled')
      mock = @sandbox.mock(softboiled).expects('fail').once()
      @battle.performMove(@p1, softboiled)
      mock.verify()

  describe 'Knock Off', ->
    it "deals damage", ->
      shared.create.call this,
        team2: [Factory('Magikarp', item: "Leftovers")]
      @battle.performMove(@p1, @battle.getMove("Knock Off"))
      @p2.currentHP.should.be.lessThan @p2.stat('hp')

    it "removes the target's item", ->
      shared.create.call this,
        team2: [Factory('Magikarp', item: "Leftovers")]
      @battle.performMove(@p1, @battle.getMove("Knock Off"))
      should.not.exist @p2.item

    it "does not remove unremovable items", ->
      shared.create.call this,
        team2: [Factory('Magikarp', item: "Air Mail")]
      @battle.performMove(@p1, @battle.getMove("Knock Off"))
      @p2.hasItem().should.be.true

    it "does not knock off items from pokemon with Sticky Hold", ->
      shared.create.call this,
        team2: [Factory('Magikarp', ability: "Sticky Hold", item: "Leftovers")]
      @battle.performMove(@p1, @battle.getMove("Knock Off"))
      @p2.hasItem().should.be.true

    it "takes damage from Rocky Helmet", ->
      shared.create.call this,
        team2: [Factory('Magikarp', item: "Rocky Helmet")]
      @battle.performMove(@p1, @battle.getMove("Knock Off"))
      @p2.hasItem().should.be.false
      @p1.currentHP.should.be.lessThan(@p1.stat('hp'))

    it "doesn't knock off if substitute fades", ->
      shared.create.call this,
        team2: [Factory('Magikarp', item: "Leftovers")]
      @p2.attach(Attachment.Substitute, hp: 1)
      @battle.performMove(@p1, @battle.getMove("Knock Off"))
      @p2.hasItem().should.be.true

    it "doesn't knock off if user is fainted", ->
      shared.create.call this,
        team2: [Factory('Magikarp', item: "Rocky Helmet")]
      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Knock Off"))
      @p2.hasItem().should.be.true
      @p1.isFainted().should.be.true

    it 'removes healing Berries before they can activate', ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Sitrus Berry")]
      @p2.currentHP = 2
      move = @battle.getMove('Knock Off')
      @sandbox.stub(move, 'calculateDamage', -> 1)
      @battle.performMove(@p1, move)
      @p2.currentHP.should.equal 1

  describe 'trick and switcheroo', ->
    shared.shouldDoNoDamage('Trick')

    it "isn't affected by type-immunities", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Stick')]
        team2: [Factory('Drapion', item: "Leftovers")]
      item1 = @p1.item
      item2 = @p2.item

      trick = @battle.getMove('Trick')
      @battle.performMove(@p1, trick)
      @p2.item.should.equal item1
      @p1.item.should.equal item2

    it "swaps the target and user's item", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Stick')]
        team2: [Factory('Magikarp', item: "Leftovers")]
      item1 = @p1.item
      item2 = @p2.item
      @controller.makeMove(@id1, 'Trick')
      @controller.makeMove(@id2, 'Splash')

      @p2.item.should.equal item1
      @p1.item.should.equal item2

    it "fails if the user has Sticky Hold", ->
      shared.create.call this,
        team1: [Factory('Alakazam', ability: "Sticky Hold", item: 'Stick')]
        team2: [Factory('Gastrodon', item: "Leftovers")]
      trick = @battle.getMove('Trick')
      mock = @sandbox.mock(trick).expects('fail').once()
      @battle.performMove(@p1, trick)
      mock.verify()

    it "fails if the target has Sticky Hold", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Stick')]
        team2: [Factory('Magikarp', ability: "Sticky Hold", item: "Leftovers")]
      trick = @battle.getMove('Trick')
      mock = @sandbox.mock(trick).expects('fail').once()
      @battle.performMove(@p1, trick)
      mock.verify()

    it "succeeds if only one pokemon has an item", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Stick')]
        team2: [Factory('Magikarp')]
      trick = @battle.getMove('Trick')
      item1 = @p1.item
      @battle.performMove(@p1, trick)
      should.not.exist(@p1.item)
      @p2.item.should.equal(item1)

    it "fails if neither the user nor the target has an item", ->
      shared.create.call this,
        team1: [Factory('Alakazam')]
        team2: [Factory('Magikarp')]
      trick = @battle.getMove('Trick')
      mock = @sandbox.mock(trick).expects('fail').once()
      @battle.performMove(@p1, trick)
      mock.verify()

    it "fails if the user is holding a Mail", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Air Mail')]
        team2: [Factory('Magikarp')]
      trick = @battle.getMove('Trick')
      mock = @sandbox.mock(trick).expects('fail').once()
      @battle.performMove(@p1, trick)
      mock.verify()

    it "fails if the target is holding a Mail", ->
      shared.create.call this,
        team1: [Factory('Alakazam')]
        team2: [Factory('Magikarp', item: 'Air Mail')]
      trick = @battle.getMove('Trick')
      mock = @sandbox.mock(trick).expects('fail').once()
      @battle.performMove(@p1, trick)
      mock.verify()

    it "fails if the user is Giratina-O", ->
      shared.create.call this,
        team1: [Factory('Giratina', forme: "origin")]
      trick = @battle.getMove('Trick')
      mock = @sandbox.mock(trick).expects('fail').once()
      @battle.performMove(@p1, trick)
      mock.verify()

    it "fails if the target is Giratina-O", ->
      shared.create.call this,
        team2: [Factory('Giratina', forme: "origin")]
      trick = @battle.getMove('Trick')
      mock = @sandbox.mock(trick).expects('fail').once()
      @battle.performMove(@p1, trick)
      mock.verify()

    it "fails if the target has a Substitute", ->
      shared.create.call(this)
      trick = @battle.getMove('Trick')
      substitute = @battle.getMove('Substitute')
      mock = @sandbox.mock(trick).expects('fail').once()
      @battle.performMove(@p2, substitute)
      @battle.performMove(@p1, trick)
      mock.verify()

    it "fails if the user has Multitype with a plate item", ->
      shared.create.call this,
        team1: [Factory('Magikarp', ability: "Multitype", item: "Grass Plate")]
        team2: [Factory('Magikarp')]
      trick = @battle.getMove('Trick')
      mock = @sandbox.mock(trick).expects('fail').once()
      @battle.performMove(@p1, trick)
      mock.verify()

    it "fails if the target has Multitype with a plate item", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', ability: "Multitype", item: "Grass Plate")]
      trick = @battle.getMove('Trick')
      mock = @sandbox.mock(trick).expects('fail').once()
      @battle.performMove(@p1, trick)
      mock.verify()

    it "fails if the target is Genesect with a Drive item", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Genesect', item: "Burn Drive")]
      trick = @battle.getMove('Trick')
      mock = @sandbox.mock(trick).expects('fail').once()
      @battle.performMove(@p1, trick)
      mock.verify()

    it "fails if the user is Genesect with a Drive item", ->
      shared.create.call this,
        team1: [Factory('Genesect', item: "Burn Drive")]
        team2: [Factory('Magikarp')]
      trick = @battle.getMove('Trick')
      mock = @sandbox.mock(trick).expects('fail').once()
      @battle.performMove(@p1, trick)
      mock.verify()

  describe 'memento', ->
    shared.shouldDoNoDamage('Memento')

    it "faints the user", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Memento"))
      @p1.isFainted().should.be.true

    it "reduces the attack and special attack of the target by two stages", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Memento"))
      @p2.stages.should.containEql attack: -2, specialAttack: -2

    it "doesn't reduce stats if target is protected, and doesn't faint user", ->
      shared.create.call(this)
      @battle.recordMove(@id2, @battle.getMove("Protect"))
      @battle.recordMove(@id1, @battle.getMove("Memento"))
      @battle.continueTurn()
      @p2.stages.should.not.containEql attack: -2, specialAttack: -2
      @p1.isFainted().should.be.false

    it "doesn't reduce stats if target has a substitute, and doesn't faint user", ->
      shared.create.call(this)
      @battle.performMove(@p2, @battle.getMove("Substitute"))
      @battle.performMove(@p1, @battle.getMove("Memento"))
      @p2.stages.should.not.containEql attack: -2, specialAttack: -2
      @p1.isFainted().should.be.false

    it "doesn't reduce stats if target has Clear Body, but faints user", ->
      shared.create.call(this, team2: [Factory('Magikarp', ability: 'Clear Body')])
      @battle.performMove(@p1, @battle.getMove("Memento"))
      @p2.stages.should.not.containEql attack: -2, specialAttack: -2
      @p1.isFainted().should.be.true

  describe 'magnitude', ->
    it "has variable base power", ->
      shared.create.call this,
        team1: [Factory('Dugtrio')]
        team2: [Factory('Magikarp')]
      move = @battle.getMove('Magnitude')
      shared.biasRNG.call(this, "randInt", 'magnitude', 50)
      move.basePower(@battle, @p1, @p2).should.equal 70

  describe 'Pain Split', ->
    it "doesn't make a pokemon's HP go over their max", ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Blissey')]
      @controller.makeMove(@id1, 'Pain Split')
      @controller.makeMove(@id1, 'Seismic Toss')

      @p1.currentHP.should.equal @p1.stat('hp')

    it "averages user and target current HP", ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Blissey')]
      @p1.currentHP = 2
      @controller.makeMove(@id1, 'Pain Split')
      @controller.makeMove(@id2, 'Seismic Toss')

      @p1.currentHP.should.equal Math.min(326, @p1.stat('hp'))
      @p2.currentHP.should.equal Math.min(326, @p2.stat('hp'))

    it "affects Ghosts", ->
      shared.create.call this,
        team2: [Factory('Gengar')]
      painSplit = @battle.getMove("Pain Split")
      mock = @sandbox.mock(painSplit).expects('hit').once()
      @battle.performMove(@p1, painSplit)
      mock.verify()

    it "is blocked by Protect", ->
      shared.create.call(this)
      @p1.currentHP = 1
      painSplit = @battle.getMove("Pain Split")
      mock = @sandbox.mock(painSplit).expects('hit').never()
      @battle.recordMove(@id1, painSplit)
      @battle.determineTurnOrder()
      @battle.performMove(@p2, @battle.getMove("Protect"))
      @battle.performMove(@p1, painSplit)
      mock.verify()
      @p1.currentHP.should.equal(1)
      @p2.currentHP.should.equal(@p2.stat('hp'))

  describe 'Belly Drum', ->
    shared.shouldDoNoDamage('Belly Drum')

    it "maximizes attack", ->
      shared.create.call this,
        team1: [Factory('Poliwrath')]
        team2: [Factory('Magikarp')]
      @p1.stages.attack = -6
      @controller.makeMove(@id1, 'Belly Drum')
      @controller.makeMove(@id2, 'Splash')

      @p1.stages.attack.should.equal 6

    it "cuts the pokemon's HP by half", ->
      shared.create.call this,
        team1: [Factory('Poliwrath')]
        team2: [Factory('Magikarp')]
      @controller.makeMove(@id1, 'Belly Drum')
      @controller.makeMove(@id2, 'Splash')

      hp = @p1.stat('hp')
      (hp - @p1.currentHP).should.equal Math.floor(hp / 2)

    it "fails if the pokemon's HP is less than half", ->
      shared.create.call this,
        team1: [Factory('Poliwrath')]
        team2: [Factory('Magikarp')]
      hp = @p1.currentHP = Math.floor(@p1.stat('hp') / 2) - 1
      @controller.makeMove(@id1, 'Belly Drum')
      @controller.makeMove(@id2, 'Splash')

      @p1.currentHP.should.equal hp
      @p1.stages.attack.should.equal 0

    it "fails if the pokemon's attack is already maximized", ->
      shared.create.call this,
        team1: [Factory('Poliwrath')]
        team2: [Factory('Magikarp')]
      @p1.boost(attack: 12)
      bd = @battle.getMove('Belly Drum')
      mock = @sandbox.mock(bd).expects('fail').once()

      @battle.performMove(@p1, bd)
      mock.verify()
      @p1.currentHP.should.equal(@p1.stat('hp'))

  describe 'acupressure', ->
    shared.shouldDoNoDamage('Acupressure')

    it "raises a random stat that can be raised", ->
      shared.create.call this,
        team1: [Factory('Shuckle')]
        team2: [Factory('Magikarp')]
      stages = _.clone(@p1.stages)
      @controller.makeMove(@id1, 'Acupressure')
      @controller.makeMove(@id2, 'Splash')

      @p1.stages.should.not.eql stages

    it "fails if the Pokemon has maximum stats", ->
      shared.create.call this,
        team1: [Factory('Shuckle')]
        team2: [Factory('Magikarp')]
      @p1.stages.attack = 6
      @p1.stages.defense = 6
      @p1.stages.specialAttack = 6
      @p1.stages.specialDefense = 6
      @p1.stages.accuracy = 6
      @p1.stages.evasion = 6
      mock = @sandbox.mock(@p2)
      mock.expects('boost').never()

      @controller.makeMove(@id1, 'Acupressure')
      @controller.makeMove(@id2, 'Splash')

      mock.verify()

  describe 'Dragon Rage', ->
    it 'always does 40 damage', ->
      shared.create.call(this)
      move = @battle.getMove('Dragon Rage')
      move.calculateDamage(@battle, @p1, @p2).should.equal 40

  describe 'SonicBoom', ->
    it 'always does 20 damage', ->
      shared.create.call(this)
      sonicBoom = @battle.getMove('SonicBoom')
      sonicBoom.calculateDamage(@battle, @p1, @p2).should.equal 20

  describe 'explosion moves', ->
    it 'faints the user', ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Blissey')]
      @battle.performMove(@p1, @battle.getMove('Explosion'))
      @p1.isFainted().should.be.true

    it 'faints the user even if enemy is immune', ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Gengar')]
      @battle.performMove(@p1, @battle.getMove('Explosion'))
      @p1.isFainted().should.be.true

    it 'fails if an active Pokemon has Damp', ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Politoed', ability: 'Damp')]
      explosion = @battle.getMove('Explosion')
      mock = @sandbox.mock(explosion).expects('fail').once()
      @battle.performMove(@p1, explosion)
      mock.verify()

  describe 'endeavor', ->
    it "brings the target's hp down to the user's hp", ->
      shared.create.call(this)
      hp = 4
      @p1.currentHP = hp
      @battle.performMove(@p1, @battle.getMove('Endeavor'))
      @p2.currentHP.should.equal hp

    it "fails if the target's hp is less than the user's hp", ->
      shared.create.call(this)
      move = @battle.getMove('Endeavor')
      mock = @sandbox.mock(move).expects('fail').once()
      @p2.currentHP = hp = 4

      @battle.performMove(@p1, move)
      mock.verify()

    it "doesn't hit ghost pokemon", ->
      shared.create.call this,
        team1: [Factory('Politoed')]
        team2: [Factory('Gengar')]
      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Endeavor'))
      @p2.currentHP.should.equal @p2.stat('hp')

  describe 'a thief move', ->
    it "should steal the target's item", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Leftovers")]
      item2 = @p2.item
      @battle.performMove(@p1, @battle.getMove('Thief'))
      @p1.item.should.equal item2
      should.not.exist @p2.item

    it "should not steal the target's item if it has none", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp')]
      item2 = @p2.item
      @battle.performMove(@p1, @battle.getMove('Thief'))
      should.not.exist @p1.item
      should.not.exist @p2.item

    it "should not steal the target's item if user already has an item", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: "Stick")]
        team2: [Factory('Magikarp', item: "Leftovers")]
      item1 = @p1.item
      item2 = @p2.item
      @battle.performMove(@p1, @battle.getMove('Thief'))
      @p1.item.should.equal item1
      @p2.item.should.equal item2

    it "should not steal the target's item if target has Sticky Hold", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Leftovers", ability: "Sticky Hold")]
      item2 = @p2.item
      @battle.performMove(@p1, @battle.getMove('Thief'))
      should.not.exist @p1.item
      @p2.item.should.equal item2

    it "should not steal target's item if target has Multitype and a plate", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Draco Plate", ability: "Multitype")]
      item2 = @p2.item
      @battle.performMove(@p1, @battle.getMove('Thief'))
      should.not.exist @p1.item
      @p2.item.should.equal item2

    it "should not steal the target's item if the target has no item", ->
      shared.create.call(this)
      item2 = @p2.item
      @battle.performMove(@p1, @battle.getMove('Thief'))
      @p1.hasItem().should.be.false
      @p2.hasItem().should.be.false

    it "should not steal the target's item if target is Giratina-O", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Giratina', forme: "origin", item: "Griseous Orb")]
      item2 = @p2.item
      @battle.performMove(@p1, @battle.getMove('Thief'))
      should.not.exist @p1.item
      @p2.item.should.equal item2

    it "should not steal the target's item if target is Genesect with Drive", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Genesect', item: "Burn Drive")]
      item2 = @p2.item
      @battle.performMove(@p1, @battle.getMove('Thief'))
      should.not.exist @p1.item
      @p2.item.should.equal item2

    it "should not steal the target's item if target holds Mail", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Air Mail")]
      item2 = @p2.item
      @battle.performMove(@p1, @battle.getMove('Thief'))
      should.not.exist @p1.item
      @p2.item.should.equal item2

    it "should not steal the target's item if user is fainted", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Leftovers", ability: "Iron Barbs")]
      item2 = @p2.item
      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Thief'))
      should.not.exist @p1.item
      @p2.item.should.equal item2

  describe 'crush grip', ->
    it 'has a base power of 1 minimum', ->
      shared.create.call(this)
      move = @battle.getMove('Crush Grip')
      @p2.currentHP = 1
      move.basePower(@battle, @p1, @p2).should.equal 1

    it 'has a base power of 121 maximum', ->
      shared.create.call(this)
      move = @battle.getMove('Crush Grip')
      @p2.currentHP = @p2.stat('hp')
      move.basePower(@battle, @p1, @p2).should.equal 121

  describe 'hex', ->
    it 'doubles the base power if target is burned, poisoned, or paralyzed', ->
      shared.create.call(this)
      move = @battle.getMove('Hex')
      @p2.attach(Status.Paralyze)
      move.basePower(@battle, @p1, @p2).should.equal 100

  describe 'heavy slam and heat crash', ->
    it 'has variable base power based on the difference in weight', ->
      shared.create.call(this)
      move = @battle.getMove('Heavy Slam')
      move.basePower(@battle, @p1, @p2).should.equal 40
      move.basePower(@battle, @p1, calculateWeight: -> -1000).should.equal 120

  describe 'a status cure move', ->
    it 'heals the entire team of status effects', ->
      shared.create.call this,
        team1: [Factory('Magikarp'), Factory('Magikarp'), Factory('Magikarp')]
      shared.biasRNG.call(this, 'next', 'paralyze chance', 1)  # never pars
      @team1.pokemon.forEach((pokemon) -> pokemon.attach(Status.Paralyze))
      @battle.performMove(@p1, @battle.getMove('Aromatherapy'))

      _.all(@team1.pokemon, (pokemon) -> !pokemon.hasStatus()).should.be.true

  describe 'copycat', ->
    beforeEach ->
      shared.create.call this,
        team1: [Factory('Magikarp', evs: {speed: 4})] # make faster than team2

    it 'copies the last move used', ->
      @battle.lastMove = @battle.getMove('Tackle')
      mock = @sandbox.mock(@battle.getMove('Tackle'))
      mock.expects('execute').once()
      @battle.performMove(@p1, @battle.getMove('Copycat'))
      mock.verify()

    it "changes the move's target properly", ->
      tackle = @battle.getMove('Tackle')
      @battle.lastMove = tackle
      mock = @sandbox.mock(tackle)
      mock.expects('execute').once().withArgs(@battle, @p1, [ @p2 ])
      @battle.performMove(@p1, @battle.getMove('Copycat'))
      mock.verify()

    it 'fails if no last move was used', ->
      @battle.lastMove = null
      mock = @sandbox.mock(@battle.getMove('Copycat'))
      mock.expects('fail').once()
      @battle.performMove(@p1, @battle.getMove('Copycat'))
      mock.verify()

    it 'fails if the last move was copycat', ->
      @battle.lastMove = @battle.getMove('Copycat')
      mock = @sandbox.mock(@battle.getMove('Copycat'))
      mock.expects('fail').once()
      @battle.performMove(@p1, @battle.getMove('Copycat'))
      mock.verify()

  describe 'a move that targets a different stat', ->
    it "uses the correct stat", ->
      shared.create.call(this)
      move = @battle.getMove('Secret Sword')
      defStat = @p2.stat('defense')
      move.pickDefenseStat(@p1, @p2).should.equal defStat

  describe 'foul play', ->
    it "uses the target's attack stat, not the user's", ->
      shared.create.call this,
        team1: [Factory('Celebi')]
      move = @battle.getMove('Foul Play')
      atkStat = @p2.stat('attack')
      move.pickAttackStat(@p1, @p2).should.equal atkStat

  describe 'foul play', ->
    it "uses the target's attack stat, not the user's", ->
      shared.create.call this,
        team1: [Factory('Celebi')]
      move = @battle.getMove('Foul Play')
      atkStat = @p2.stat('attack')
      move.pickAttackStat(@p1, @p2).should.equal atkStat

  describe 'teleport', ->
    it "always fails", ->
      shared.create.call(this)
      move = @battle.getMove('Teleport')
      mock = @sandbox.mock(move).expects('fail').once()
      @battle.performMove(@p1, move)
      mock.verify()

  describe 'Super Fang', ->
    it "deals half of the target's current HP", ->
      shared.create.call(this)
      hp = @p2.currentHP
      hp = @p2.currentHP = (hp - (1 - hp % 2))  # Always odd
      @battle.performMove(@p1, @battle.getMove('Super Fang'))
      @p2.currentHP.should.equal Math.ceil(hp / 2)

    it "deals 1 damage minimum", ->
      shared.create.call(this)
      @p2.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Super Fang'))
      @p2.currentHP.should.equal 0

  describe "A weather-based recovery move", ->
    it "heals 50% HP in no weather, rounded half down", ->
      shared.create.call(this)
      @battle.setWeather(Weather.NONE)
      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Moonlight'))

      hp = util.roundHalfDown(@p1.stat('hp') / 2)
      @p1.currentHP.should.equal(1 + hp)

    it "heals 25% HP in bad weather, rounded half down", ->
      shared.create.call(this, team1: [Factory("Shuckle")])
      @battle.setWeather(Weather.SAND)
      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Moonlight'))

      hp = util.roundHalfDown(@p1.stat('hp') / 4)
      @p1.currentHP.should.equal(1 + hp)

    it "heals 66% HP in good weather, rounded half down", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SUN)
      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Moonlight'))

      hp = util.roundHalfDown(@p1.stat('hp') * 2 / 3)
      @p1.currentHP.should.equal(1 + hp)

  describe 'a flinching move', ->
    it "prevents the other person from executing their move", ->
      shared.create.call(this)

      mock = @sandbox.mock(@battle.getMove('Splash'))
      mock.expects('execute').never()

      @battle.performMove(@p1, @battle.getMove('Fake Out'))
      @battle.performMove(@p2, @battle.getMove('Splash'))

      mock.verify()

    it "removes the flinch attachment at the end of the turn", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove('Fake Out'))
      @battle.endTurn()
      @p2.has(Attachment.Flinch).should.be.false

  describe 'weather ball', ->
    it "is a 50 base power normal move in normal conditions", ->
      shared.create.call(this)
      @battle.setWeather(Weather.NONE)

      move = @battle.getMove('Weather Ball')
      move.getType(@battle, @p1, @p2).should.equal 'Normal'
      move.basePower(@battle, @p1, @p2).should.equal 50

    it "is a 100 base power Water move in rain", ->
      shared.create.call(this)
      @battle.setWeather(Weather.RAIN)

      move = @battle.getMove('Weather Ball')
      move.getType(@battle, @p1, @p2).should.equal 'Water'
      move.basePower(@battle, @p1, @p2).should.equal 100

    it "is a 100 base power Fire move in sun", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SUN)

      move = @battle.getMove('Weather Ball')
      move.getType(@battle, @p1, @p2).should.equal 'Fire'
      move.basePower(@battle, @p1, @p2).should.equal 100

    it "is a 100 base power Ice move in hail", ->
      shared.create.call(this)
      @battle.setWeather(Weather.HAIL)

      move = @battle.getMove('Weather Ball')
      move.getType(@battle, @p1, @p2).should.equal 'Ice'
      move.basePower(@battle, @p1, @p2).should.equal 100

    it "is a 100 base power Rock move in sandstorm", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SAND)

      move = @battle.getMove('Weather Ball')
      move.getType(@battle, @p1, @p2).should.equal 'Rock'
      move.basePower(@battle, @p1, @p2).should.equal 100

  describe 'Autotomize', ->
    it 'changes your weight on success', ->
      shared.create.call(this)
      weight = @p1.calculateWeight()
      @battle.performMove(@p1, @battle.getMove('Autotomize'))

      weight.should.not.equal @p1.calculateWeight()

    it 'cannot go below .1kg', ->
      # Magikarp weighs 100kg.
      shared.create.call this, team1: [ Factory('Magikarp')]
      @battle.performMove(@p1, @battle.getMove('Autotomize'))

      @p1.calculateWeight().should.not.be.lessThan .1

    it 'stacks weight changes', ->
      # Abomasnow weighs 1355kg.
      shared.create.call this, team1: [ Factory('Abomasnow')]

      @battle.performMove(@p1, @battle.getMove('Autotomize'))
      @battle.performMove(@p1, @battle.getMove('Autotomize'))

      @p1.calculateWeight().should.equal 1155

  describe 'heart swap', ->
    shared.shouldDoNoDamage('Heart Swap')

    it 'swaps user and target boosts', ->
      shared.create.call(this)
      @p1.stages.attack = 2
      @p2.stages.speed = -2

      @battle.performMove(@p1, @battle.getMove('Heart Swap'))

      @p1.stages.should.containEql speed: -2
      @p2.stages.should.containEql attack: 2

  describe 'Nightmare', ->
    shared.shouldDoNoDamage('Nightmare')

    it 'fails if the pokemon is awake', ->
      shared.create.call(this)
      mock = @sandbox.mock(@battle.getMove('Nightmare')).expects('fail').once()
      @battle.performMove(@p1, @battle.getMove('Nightmare'))
      mock.verify()

    it 'fails if used twice', ->
      shared.create.call(this)
      shared.biasRNG.call(this, 'randInt', 'sleep turns', 3)
      nightmare = @battle.getMove('Nightmare')
      @p2.attach(Status.Sleep)

      mock = @sandbox.mock(nightmare).expects('fail').once()
      @battle.performMove(@p1, nightmare)
      @battle.performMove(@p1, nightmare)
      mock.verify()

    it "cuts the target's HP by 25% each turn", ->
      shared.create.call(this)
      shared.biasRNG.call(this, 'randInt', 'sleep turns', 3)
      @p2.attach(Status.Sleep)

      hp = @p2.currentHP
      quarter = Math.floor(hp / 4)

      @battle.performMove(@p1, @battle.getMove('Nightmare'))
      @battle.endTurn()
      @p2.currentHP.should.equal(hp - quarter)

      @battle.endTurn()
      @p2.currentHP.should.equal(hp - 2*quarter)

    it "deals 1 damage minimum", ->
      shared.create.call(this, team2: [Factory("Shedinja")])
      shared.biasRNG.call(this, 'randInt', 'sleep turns', 3)
      @p2.attach(Status.Sleep)

      @battle.performMove(@p1, @battle.getMove('Nightmare'))
      @battle.endTurn()
      @p2.currentHP.should.equal(0)

    it "stops the nightmare if the target wakes up", ->
      shared.create.call(this)
      shared.biasRNG.call(this, 'randInt', 'sleep turns', 3)
      @p2.attach(Status.Sleep)

      @battle.performMove(@p1, @battle.getMove('Nightmare'))

      @p2.cureStatus()
      @battle.endTurn()  # The check is in endTurn()
      @p2.has(Attachment.Nightmare).should.be.false

  describe 'Incinerate', ->
    it 'destroys the berry of the target', ->
      shared.create.call this,
        team2: [ Factory('Magikarp', item: 'Bluk Berry') ]

      @battle.performMove(@p1, @battle.getMove('Incinerate'))
      should.not.exist @p2.item

    it 'does not destroy non-berries', ->
      shared.create.call this,
        team2: [ Factory('Magikarp', item: 'Leftovers') ]

      @battle.performMove(@p1, @battle.getMove('Incinerate'))
      should.exist @p2.item

  describe 'Judgment', ->
    it 'is normal type by default', ->
      shared.create.call(this)
      move = @battle.getMove('Judgment')
      move.getType(@battle, @p1, @p2).should.equal 'Normal'

    it 'changes type depending on the Plate held by the user', ->
      shared.create.call this,
        team1: [ Factory('Magikarp', item: 'Earth Plate') ]
      move = @battle.getMove('Judgment')
      move.getType(@battle, @p1, @p2).should.equal 'Ground'

  describe 'Tailwind', ->
    shared.shouldDoNoDamage("Tailwind")
    shared.shouldFailIfUsedTwice("Tailwind")

    it "doubles the speed of the user's team", ->
      shared.create.call this

      oldSpeed = @p1.stat('speed')
      @battle.performMove(@p1, @battle.getMove('Tailwind'))
      newSpeed = @p1.stat('speed')
      newSpeed.should.equal(oldSpeed * 2)

    it "lasts three turns", ->
      shared.create.call(this)

      @battle.performMove(@p1, @battle.getMove('Tailwind'))
      @battle.endTurn()
      @battle.endTurn()
      @battle.endTurn()
      @battle.endTurn()

      @p1.team.has(Attachment.Tailwind).should.be.false

  describe 'Taunt', ->
    shared.shouldDoNoDamage("Taunt")
    shared.shouldFailIfUsedTwice("Taunt")

    it 'prevents the target from using a non-attacking move that turn', ->
      shared.create.call(this, team1: [ Factory('Magikarp', evs: {speed: 4}) ])
      move = @battle.getMove('Calm Mind')
      taunt = @battle.getMove('Taunt')
      mock = @sandbox.mock(move)
      mock.expects('execute').never()

      @battle.performMove(@p1, taunt)
      @battle.performMove(@p2, move)

      mock.verify()

    it "lasts 4 turns if the user moved after the target", ->
      shared.create.call(this, team1: [Factory("Magikarp", evs: {speed: 4})])
      @battle.performMove(@p1, @battle.getMove('Splash'))
      @battle.performMove(@p2, @battle.getMove('Taunt'))

      @p1.has(Attachment.Taunt).should.be.true

      @battle.endTurn()
      @battle.endTurn()
      @battle.endTurn()
      @p1.has(Attachment.Taunt).should.be.true
      @battle.endTurn()

      @p1.has(Attachment.Taunt).should.be.false

    it "lasts 3 turns if the user moved before the target", ->
      shared.create.call(this, team1: [Factory("Magikarp", evs: {speed: 4})])
      @battle.performMove(@p2, @battle.getMove('Splash'))
      @battle.recordMove(@id1, @battle.getMove('Taunt'))
      @battle.recordMove(@id2, @battle.getMove('Tackle'))
      @battle.continueTurn()

      @p2.has(Attachment.Taunt).should.be.true

      @battle.endTurn()
      @battle.endTurn()
      @p2.has(Attachment.Taunt).should.be.true
      @battle.endTurn()

      @p2.has(Attachment.Taunt).should.be.false

    it 'prevents the target from selecting that move the next turn', ->
      shared.create.call(this)

      @battle.performMove(@p1, @battle.getMove('Taunt'))
      @battle.beginTurn()
      requestedMoves = @battle.requestFor(@p2).moves
      requestedMoves.should.not.containEql 'Splash'

  for moveName in [ "U-turn", "Volt Switch" ]
    do (moveName) ->
      describe moveName, ->
        it 'forces the owner to switch', ->
          shared.create.call(this, team1: (Factory("Magikarp")  for i in [1..2]))
          @battle.performMove(@p1, @battle.getMove(moveName))

          @battle.requests.should.have.property(@id1)

        it "makes a request containing all the possible switches", ->
          shared.create.call(this, team1: (Factory("Magikarp")  for i in [1..3]))
          @battle.performMove(@p1, @battle.getMove(moveName))
          request = @battle.requestFor(@p1)
          request.switches.should.eql([ 1, 2 ])

  describe 'venoshock', ->
    it 'doubles the base power if target is poisoned', ->
      shared.create.call(this)
      move = @battle.getMove("Venoshock")
      @p2.attach(Status.Poison)
      basePower = move.basePower(@battle, @p1, @p2)
      basePower.should.equal(2 * move.power)

    it 'doubles the base power if target is toxiced', ->
      shared.create.call(this)
      move = @battle.getMove("Venoshock")
      @p2.attach(Status.Toxic)
      basePower = move.basePower(@battle, @p1, @p2)
      basePower.should.equal(2 * move.power)

  describe 'Wish', ->
    shared.shouldDoNoDamage("Wish")
    shared.shouldFailIfUsedTwice("Wish")

    it "restores half of the user's total hit points the next end of turn", ->
      shared.create.call(this)
      hp = @p1.currentHP
      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Wish'))
      @battle.endTurn()

      @p1.currentHP.should.equal 1

      @battle.endTurn()

      @p1.currentHP.should.equal(Math.round(hp / 2) + 1)

    it "restores the same total amount of HP to an ally", ->
      shared.create.call(this, team1: [Factory("Magikarp"), Factory("Celebi")])
      hp = @p1.currentHP
      @battle.performMove(@p1, @battle.getMove('Wish'))
      @battle.endTurn()
      receiver = @team1.at(1)

      receiver.currentHP = 1
      @battle.performSwitch(@p1, 1)
      @battle.endTurn()

      receiver.currentHP.should.equal(Math.round(hp / 2) + 1)

    it "fails if the pokemon faints", ->
      shared.create.call(this, team1: [Factory("Magikarp"), Factory("Celebi")])
      @battle.performMove(@p1, @battle.getMove('Wish'))
      @battle.endTurn()

      @p1.currentHP = 1
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @battle.endTurn()
      @team1.has(Attachment.Wish).should.be.false

  describe "Counter", ->
    it "returns double the damage if attacked by a physical move", ->
      shared.create.call(this)
      @battle.performMove(@p2, @battle.getMove('Tackle'))
      @battle.performMove(@p1, @battle.getMove('Counter'))

      dhp1 = @p1.stat('hp') - @p1.currentHP
      dhp2 = @p2.stat('hp') - @p2.currentHP
      dhp2.should.equal 2*dhp1

    it "fails if attacked by a special move", ->
      shared.create.call(this)
      mock = @sandbox.mock(@battle.getMove('Counter'))
      mock.expects('fail').once()
      @battle.performMove(@p2, @battle.getMove('ThunderShock'))
      @battle.performMove(@p1, @battle.getMove('Counter'))

      mock.verify()

    it "fails if not hit by an attack this turn", ->
      shared.create.call(this)
      mock = @sandbox.mock(@battle.getMove('Counter'))
      mock.expects('fail').once()
      @controller.makeMove(@id1, "Splash")
      @controller.makeMove(@id2, "Tackle")

      @battle.performMove(@p1, @battle.getMove('Counter'))
      mock.verify()

    it "hits the pokemon who is currently in that slot, not who was", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove('U-turn'))
      @battle.performSwitch(@p1, 1)
      @battle.performMove(@p2, @battle.getMove('Counter'))
      @team1.first().currentHP.should.be.lessThan(@team1.first().stat('hp'))
      @team1.at(1).currentHP.should.equal(@team1.at(1).stat('hp'))

    it "doesn't activate Rough Skin if it fails", ->
      shared.create.call this,
        team2: [Factory("Garchomp", ability: "Rough Skin")]

      counter = @battle.getMove("Counter")
      mock = @sandbox.mock(counter)
      mock.expects('fail').once()
      @battle.performMove(@p1, counter)
      mock.verify()
      @p1.currentHP.should.equal(@p1.stat('hp'))

  describe "Perish Song", ->
    it "attaches to every pokemon in the field", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove('Perish Song'))

      result = _.all @battle.getActivePokemon(), (pokemon) ->
        pokemon.has(Attachment.PerishSong)
      result.should.be.true

    it "faints pokemon at the end of 4 turns", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove('Perish Song'))
      @battle.endTurn()
      @battle.endTurn()
      @battle.endTurn()

      result = _.all @battle.getActivePokemon(), (pokemon) ->
        !pokemon.isFainted()
      result.should.be.true

      @battle.endTurn()

      result = _.all @battle.getActivePokemon(), (pokemon) ->
        pokemon.isFainted()
      result.should.be.true

    it "fails against Pokemon with Soundproof", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Soundproof")])
      @battle.performMove(@p2, @battle.getMove("Perish Song"))
      @p1.has(Attachment.PerishSong).should.be.false
      @p2.has(Attachment.PerishSong).should.be.true

  describe "Techno Blast", ->
    it "is Fire-type if the user holds a Burn Drive", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Burn Drive")]
      move = @battle.getMove('Techno Blast')
      type = move.getType(@battle, @p1, @p2)
      type.should.equal "Fire"

    it "is Water-type if the user holds a Douse Drive", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Douse Drive")]
      move = @battle.getMove('Techno Blast')
      type = move.getType(@battle, @p1, @p2)
      type.should.equal "Water"

    it "is Electric-type if the user holds a Shock Drive", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Shock Drive")]
      move = @battle.getMove('Techno Blast')
      type = move.getType(@battle, @p1, @p2)
      type.should.equal "Electric"

    it "is Ice-type if the user holds a Chill Drive", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Chill Drive")]
      move = @battle.getMove('Techno Blast')
      type = move.getType(@battle, @p1, @p2)
      type.should.equal "Ice"

    it "is Normal-type otherwise", ->
      shared.create.call(this)
      move = @battle.getMove('Techno Blast')
      type = move.getType(@battle, @p1, @p2)
      type.should.equal "Normal"

  describe "Synchronoise", ->
    it "fails on Pokemon not of the user's type", ->
      shared.create.call this,
        team1: [Factory("Magikarp")]
        team2: [Factory("Celebi")]

      move = @battle.getMove('Synchronoise')
      mock = @sandbox.mock(move)
      mock.expects('fail').once()

      @battle.performMove(@p1, move)
      mock.verify()

    it "works on Pokemon that share one type with the user", ->
      shared.create.call this,
        team1: [Factory("Ferrothorn")]
        team2: [Factory("Celebi")]

      hp = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Synchronoise'))
      @p2.currentHP.should.be.lessThan hp

  describe "Roost", ->
    shared.shouldDoNoDamage('Roost')

    it "removes the user's flying type during the turn", ->
      shared.create.call this,
        team1: [Factory("Gliscor")]

      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Roost"))

      ('Flying' in @p1.types).should.be.false
      @p1.types.should.eql ['Ground']

    it "turns pure-Flying pokemon into Normal pokemon", ->
      shared.create.call this,
        team1: [Factory("Tornadus")]

      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Roost"))

      ('Flying' in @p1.types).should.be.false
      @p1.types.should.eql ['Normal']

    it "keeps the user's types the same if non-Flying", ->
      shared.create.call this,
        team1: [Factory("Celebi")]

      oldTypes = @p1.types
      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Roost"))
      @p1.types.should.eql oldTypes

    it "restores the user's old types after the turn", ->
      shared.create.call this,
        team1: [Factory("Gliscor")]

      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Roost"))
      @battle.endTurn()
      ('Flying' in @p1.types).should.be.true
      ('Ground' in @p1.types).should.be.true

  describe 'Encore', ->
    shared.shouldDoNoDamage('Encore')

    it "fails if the target has not yet used a move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", evs: {speed: 4})]
      encore = @battle.getMove('Encore')
      mock = @sandbox.mock(encore).expects('fail').once()

      @battle.performMove(@p1, encore)
      mock.verify()

    it "forces the target to repeat its last used move", ->
      shared.create.call(this)

      @battle.performMove(@p2, @battle.getMove('Splash'))
      @battle.performMove(@p1, @battle.getMove('Encore'))

      @battle.beginTurn()
      @p2.validMoves().should.eql [ @battle.getMove('Splash') ]

    it "changes the target's decision if it has not moved yet", ->
      shared.create.call(this, team1: [Factory("Magikarp", evs: {speed: 4})])

      @battle.performMove(@p2, @battle.getMove('Splash'))
      @battle.recordMove(@id1, @battle.getMove('Encore'))
      @battle.recordMove(@id2, @battle.getMove('Tackle'))
      @battle.continueTurn()
      @p2.lastMove.should.equal @battle.getMove('Splash')

    it "lasts 4 turns if the user moved after the target", ->
      shared.create.call(this, team1: [Factory("Magikarp", evs: {speed: 4})])
      @battle.performMove(@p1, @battle.getMove('Splash'))
      @battle.performMove(@p2, @battle.getMove('Encore'))

      @p1.has(Attachment.Encore).should.be.true

      @battle.endTurn()
      @battle.endTurn()
      @battle.endTurn()
      @p1.has(Attachment.Encore).should.be.true
      @battle.endTurn()

      @p1.has(Attachment.Encore).should.be.false

    it "lasts 3 turns if the user moved before the target", ->
      shared.create.call(this, team1: [Factory("Magikarp", evs: {speed: 4})])
      @battle.performMove(@p2, @battle.getMove('Splash'))
      @battle.recordMove(@id1, @battle.getMove('Encore'))
      @battle.recordMove(@id2, @battle.getMove('Tackle'))
      @battle.continueTurn()

      @p2.has(Attachment.Encore).should.be.true

      @battle.endTurn()
      @battle.endTurn()
      @p2.has(Attachment.Encore).should.be.true
      @battle.endTurn()

      @p2.has(Attachment.Encore).should.be.false

    it "fails on certain moves like mimic", ->
      shared.create.call(this)
      encore = @battle.getMove('Encore')
      mock = @sandbox.mock(encore).expects('fail').once()

      @battle.performMove(@p2, @battle.getMove('Mimic'))
      @battle.performMove(@p1, @battle.getMove('Encore'))
      mock.verify()

    it "fails if the pokemon is already encored", ->
      shared.create.call(this)
      encore = @battle.getMove('Encore')
      mock = @sandbox.mock(encore).expects('fail').once()

      @battle.performMove(@p2, @battle.getMove('Splash'))
      @battle.performMove(@p1, @battle.getMove('Encore'))
      @battle.performMove(@p1, @battle.getMove('Encore'))
      mock.verify()

    it "fails if the move has 0 PP", ->
      shared.create.call(this)
      encore = @battle.getMove('Encore')
      mock = @sandbox.mock(encore).expects('fail').once()

      @p2.setPP(@battle.getMove('Splash'), 1)
      @battle.performMove(@p2, @battle.getMove('Splash'))
      @battle.performMove(@p1, @battle.getMove('Encore'))
      mock.verify()

    it "removes itself if the pokemon's move reaches 0 PP", ->
      shared.create.call(this)

      @p2.setPP(@battle.getMove('Splash'), 2)
      @battle.performMove(@p2, @battle.getMove('Splash'))
      @battle.performMove(@p1, @battle.getMove('Encore'))
      @battle.endTurn()

      @p2.has(Attachment.Encore).should.be.true

      @battle.performMove(@p2, @battle.getMove('Splash'))
      @battle.endTurn()

      @p2.has(Attachment.Encore).should.be.false

  describe "Swagger", ->
    it "confuses the target", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Swagger"))
      @p2.has(Attachment.Confusion).should.be.true

    it "boosts the target's attack by two stages", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Swagger"))
      @p2.stages.attack.should.equal 2

  describe "Flatter", ->
    it "confuses the target", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Flatter"))
      @p2.has(Attachment.Confusion).should.be.true

    it "boosts the target's special attack by one stage", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Flatter"))
      @p2.stages.specialAttack.should.equal 1

  describe "Torment", ->
    shared.shouldDoNoDamage("Torment")
    shared.shouldFailIfUsedTwice("Torment")

    it "prevents the target from using its last move", ->
      shared.create.call(this)

      @battle.performMove(@p1, @battle.getMove("Torment"))
      @battle.performMove(@p2, @battle.getMove("Splash"))
      @battle.beginTurn()
      @p2.validMoves().should.eql [ @battle.getMove('Tackle') ]

      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @battle.beginTurn()
      @p2.validMoves().should.eql [ @battle.getMove('Splash') ]

    it "still works even if a new pokemon has just switched in", ->
      shared.create.call(this, team2: [Factory("Magikarp"), Factory("Magikarp")])

      @battle.performSwitch(@p2, 1)
      @battle.performMove(@p1, @battle.getMove("Torment"))
      @battle.beginTurn()
      @team2.first().validMoves().should.eql [ @battle.getMove('Splash'), @battle.getMove('Tackle') ]

    xit "does not force the Outrage user to struggle", ->
    xit "does not prevent consecutive use of Struggle", ->

  describe "Psych Up", ->
    it "copies the target's stat changes", ->
      shared.create.call(this)

      @p1.stages.specialAttack = 5
      @p1.stages.evasion = 2
      @p2.stages.attack = 6
      @p2.stages.defense = -2
      @p2.stages.speed = -1
      @battle.performMove(@p1, @battle.getMove("Psych Up"))
      @p1.stages.should.eql {
        attack: 6, defense: -2, specialAttack: 0, specialDefense: 0,
        speed: -1, accuracy: 0, evasion: 0
      }

  describe "Spikes", ->
    it "puts a layer of spikes on the opponents' field", ->
      shared.create.call(this)

      @team2.has(Attachment.Spikes).should.be.false
      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @team2.has(Attachment.Spikes).should.be.true

    it "fails if there are 3 layers", ->
      shared.create.call(this)

      mock = @sandbox.mock(@battle.getMove('Spikes')).expects('fail').once()

      for i in [1..4]
        @battle.performMove(@p1, @battle.getMove("Spikes"))

      mock.verify()

    it "deals a minimum of 1 damage", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Shedinja")]

      @battle.performMove(@p1, @battle.getMove("Stealth Rock"))
      @battle.performSwitch(@team2.first(), 1)

      pokemon = @team2.first()
      (pokemon.stat('hp') - pokemon.currentHP).should.equal(1)

    it "does damage to pokemon switching in according to # of layers", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Magikarp")]

      hp = @team2.first().stat('hp')
      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @battle.performSwitch(@p2, 1)

      (hp - @team2.first().currentHP).should.equal Math.floor(hp / 8)
      @team2.first().currentHP = hp

      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @battle.performSwitch(@team2.first(), 1)

      (hp - @team2.first().currentHP).should.equal Math.floor(hp / 6)
      @team2.first().currentHP = hp

      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @battle.performSwitch(@team2.first(), 1)

      (hp - @team2.first().currentHP).should.equal Math.floor(hp / 4)

    it "does not affect pokemon with immunity to ground", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Magikarp", item: "Air Balloon")]

      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @battle.performSwitch(@team2.first(), 1)

      @team2.first().currentHP.should.equal @team2.first().stat('hp')

    it "affects replacements", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Magikarp")]

      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @battle.recordSwitch(@id2, 1)
      @battle.performReplacements()

      hp = @team2.first().stat('hp')
      (hp - @team2.first().currentHP).should.equal Math.floor(hp / 8)

  describe "Stealth Rock", ->
    shared.shouldDoNoDamage("Stealth Rock")
    shared.shouldFailIfUsedTwice("Stealth Rock")

    it "puts a layer of rocks on the opponents' field", ->
      shared.create.call(this)

      @team2.has(Attachment.StealthRock).should.be.false
      @battle.performMove(@p1, @battle.getMove("Stealth Rock"))
      @team2.has(Attachment.StealthRock).should.be.true

    it "does damage to pokemon switching in according to type", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Moltres")]

      @battle.performMove(@p1, @battle.getMove("Stealth Rock"))
      @battle.performSwitch(@team2.first(), 1)

      pokemon = @team2.first()

      hp = pokemon.stat('hp')
      (hp - pokemon.currentHP).should.equal Math.floor(hp / 2)

      @battle.performSwitch(@team2.first(), 1)
      pokemon = @team2.first()
      hp = pokemon.stat('hp')
      (hp - pokemon.currentHP).should.equal Math.floor(hp / 8)

    it "deals a minimum of 1 damage", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Aron", level: 1)]

      @battle.performMove(@p1, @battle.getMove("Stealth Rock"))
      @battle.performSwitch(@team2.first(), 1)

      pokemon = @team2.first()
      (pokemon.stat('hp') - pokemon.currentHP).should.equal(1)

    it "affects replacements", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Magikarp")]

      @battle.performMove(@p1, @battle.getMove("Stealth Rock"))
      @battle.recordSwitch(@id2, 1)
      @battle.performReplacements()

      hp = @team2.first().stat('hp')
      (hp - @team2.first().currentHP).should.equal Math.floor(hp / 8)

  describe "Toxic Spikes", ->
    it "puts a layer of toxic spikes on the opponents' field", ->
      shared.create.call(this)

      @team2.has(Attachment.ToxicSpikes).should.be.false
      @battle.performMove(@p1, @battle.getMove("Toxic Spikes"))
      @team2.has(Attachment.ToxicSpikes).should.be.true

    it "fails if there are 2 layers", ->
      shared.create.call(this)

      mock = @sandbox.mock(@battle.getMove('Toxic Spikes'))
      mock.expects('fail').once()

      for i in [1..3]
        @battle.performMove(@p1, @battle.getMove("Toxic Spikes"))

      mock.verify()

    it "poisons or severely poisons the switch-in if not immune", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Magikarp")]

      @battle.performMove(@p1, @battle.getMove("Toxic Spikes"))
      @battle.performSwitch(@team2.first(), 1)
      @team2.first().has(Status.Poison).should.be.true

      @battle.performMove(@p1, @battle.getMove("Toxic Spikes"))
      @battle.performSwitch(@team2.first(), 1)
      @team2.first().has(Status.Toxic).should.be.true

    it "does not affect the pokemon if it's immune to Poison", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Ferrothorn")]

      @battle.performMove(@p1, @battle.getMove("Toxic Spikes"))
      @battle.performSwitch(@team2.first(), 1)
      @team2.first().has(Status.Poison).should.be.false

    it "does not affect the pokemon if it's immune to Ground", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Gyarados")]

      @battle.performMove(@p1, @battle.getMove("Toxic Spikes"))
      @battle.performSwitch(@team2.first(), 1)
      @team2.first().has(Status.Poison).should.be.false

    it "disappears if the pokemon switching in is a grounded Poison", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Drapion")]

      @battle.performMove(@p1, @battle.getMove("Toxic Spikes"))
      @battle.performSwitch(@team2.first(), 1)
      @team2.has(Attachment.ToxicSpikes).should.be.false

    it "doesn't disappear if the pokemon switching in is a flying Poison", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Drapion", item: "Air Balloon")]

      @battle.performMove(@p1, @battle.getMove("Toxic Spikes"))
      @battle.performSwitch(@team2.first(), 1)
      @team2.has(Attachment.ToxicSpikes).should.be.true

    it "affects replacements", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Magikarp")]

      @battle.performMove(@p1, @battle.getMove("Toxic Spikes"))
      @battle.recordSwitch(@id2, 1)
      @battle.performReplacements()

      @team2.first().has(Status.Poison).should.be.true

  testWeatherMove = (moveName, weather, item) ->
    describe moveName, ->
      it "changes the weather to #{weather.toLowerCase()} for 5 turns", ->
        shared.create.call(this)

        @battle.performMove(@p1, @battle.getMove(moveName))
        @battle.weather.should.equal(weather)
        @battle.weatherDuration.should.equal 5

      it "changes the weather to #{weather.toLowerCase()} for 8 turns if user holds a #{item}", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: item)]

        @battle.performMove(@p1, @battle.getMove(moveName))
        @battle.weather.should.equal(weather)
        @battle.weatherDuration.should.equal 8

      it "fails if the weather is already #{weather}", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: item)]
        @battle.setWeather(weather)

        theMove = @battle.getMove(moveName)
        mock = @sandbox.mock(theMove).expects('fail').once()
        @battle.performMove(@p1, theMove)
        mock.verify()

  testWeatherMove("Rain Dance", Weather.RAIN, "Damp Rock")
  testWeatherMove("Sunny Day",  Weather.SUN,  "Heat Rock")
  testWeatherMove("Hail",       Weather.HAIL, "Icy Rock")
  testWeatherMove("Sandstorm",  Weather.SAND, "Smooth Rock")

  testStatusMove = (moveName, status) ->
    describe moveName, ->
      it "changes the status on a Pokemon if it has no status", ->
        shared.create.call(this)

        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)

        @p2.has(status).should.be.true

      it "does not change the status if Pokemon already has a status", ->
        shared.create.call(this)

        oldStatus = if status == Status.Paralyze
            Status.Sleep
          else
            Status.Paralyze
        @p2.attach(oldStatus)

        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)

        @p2.has(status).should.be.false
        @p2.has(oldStatus).should.be.true

  testStatusMove("Dark Void", Status.Sleep)
  testStatusMove("GrassWhistle", Status.Sleep)
  testStatusMove("Hypnosis", Status.Sleep)
  testStatusMove("Lovely Kiss", Status.Sleep)
  testStatusMove("Poison Gas", Status.Poison)
  testStatusMove("PoisonPowder", Status.Poison)
  testStatusMove("Sing", Status.Sleep)
  testStatusMove("Sleep Powder", Status.Sleep)
  testStatusMove("Spore", Status.Sleep)
  testStatusMove("Stun Spore", Status.Paralyze)
  testStatusMove("Thunder Wave", Status.Paralyze)
  testStatusMove("Toxic", Status.Toxic)
  testStatusMove("Will-O-Wisp", Status.Burn)

  testEffectMove = (moveName, Effect) ->
    describe moveName, ->
      it "adds the effect to the Pokemon if it doesn't have it", ->
        shared.create.call(this)

        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)

        @p2.has(Effect).should.be.true

      it "fails if the Pokemon already has it", ->
        shared.create.call(this)

        move = @battle.getMove(moveName)
        mock = @sandbox.mock(move)
        mock.expects('fail').once()

        shared.biasRNG.call(this, "randInt", 'confusion turns', 4)
        @p2.attach(Effect, {@battle})

        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)

        mock.verify()

  testEffectMove 'Confuse Ray', Attachment.Confusion
  testEffectMove 'Supersonic', Attachment.Confusion
  testEffectMove 'Sweet Kiss', Attachment.Confusion
  testEffectMove 'Teeter Dance', Attachment.Confusion

  describe "Trump Card", ->
    it "has 40 base power by default", ->
      shared.create.call(this)

      @battle.getMove('Trump Card').basePower(@battle, @p1, @p2).should.equal 40

    it "has 50 base power if the move has 3 PP after use", ->
      shared.create.call this,
        team1: [Factory("Corphish")]

      pp = @p1.pp(@battle.getMove('Trump Card'))
      for x in [0...pp - 3]
        @p1.reducePP(@battle.getMove('Trump Card'))
      @p1.pp(@battle.getMove('Trump Card')).should.equal 3

      @battle.getMove('Trump Card').basePower(@battle, @p1, @p2).should.equal 50

    it "has 60 base power if the move has 2 PP after use", ->
      shared.create.call this,
        team1: [Factory("Corphish")]

      pp = @p1.pp(@battle.getMove('Trump Card'))
      for x in [0...pp - 2]
        @p1.reducePP(@battle.getMove('Trump Card'))
      @p1.pp(@battle.getMove('Trump Card')).should.equal 2

      @battle.getMove('Trump Card').basePower(@battle, @p1, @p2).should.equal 60

    it "has 80 base power if the move has 1 PP after use", ->
      shared.create.call this,
        team1: [Factory("Corphish")]

      pp = @p1.pp(@battle.getMove('Trump Card'))
      for x in [0...pp - 1]
        @p1.reducePP(@battle.getMove('Trump Card'))
      @p1.pp(@battle.getMove('Trump Card')).should.equal 1

      @battle.getMove('Trump Card').basePower(@battle, @p1, @p2).should.equal 80

    it "has 200 base power if the move has 0 PP after use", ->
      shared.create.call this,
        team1: [Factory("Corphish")]

      pp = @p1.pp(@battle.getMove('Trump Card'))
      for x in [0...pp - 0]
        @p1.reducePP(@battle.getMove('Trump Card'))
      @p1.pp(@battle.getMove('Trump Card')).should.equal 0

      @battle.getMove('Trump Card').basePower(@battle, @p1, @p2).should.equal 200

  testRandomSwitchMove = (moveName) ->
    describe moveName, ->
      it "should switch opponent out to a random member", ->
        shared.create.call(this, team2: [Factory("Magikarp"), Factory("Abra")])

        target = @team2.at(1)
        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)

        @team2.first().should.equal target

      it "does not force a switch if the target faints", ->
        shared.create.call(this, team1: [Factory("Magikarp")], team2: [Factory("Magikarp"), Factory("Abra")])

        move = @battle.getMove(moveName)

        mock = @sandbox.mock(@team2)
        # Whirlwind, Roar
        if !move.isNonDamaging()
          mock.expects("switch").never()

        @team2.at(0).setHP(1)
        @battle.performMove(@p1, move)

        mock.verify()

      it "does not force a switch if the hit was indirect", ->
        shared.create.call(this, team1: [Factory("Magikarp")], team2: [Factory("Magikarp"), Factory("Abra")])

        move = @battle.getMove(moveName)

        mock = @sandbox.mock(@team2)
        # Whirlwind, Roar
        if !move.isNonDamaging()
          mock.expects("switch").never()

        @p2.attach(Attachment.Substitute, hp: 1)
        @battle.performMove(@p1, move)

        mock.verify()

      it "does not force a switch if the user faints", ->
        shared.create.call(this, team1: [Factory("Magikarp")], team2: [Factory("Magikarp", ability: "Iron Barbs"), Factory("Abra")])

        move = @battle.getMove(moveName)

        mock = @sandbox.mock(@team2)
        # Whirlwind, Roar
        if !move.isNonDamaging()
          mock.expects("switch").never()
        else
          mock.expects("switch").once()

        @p1.currentHP = 1
        @battle.performMove(@p1, move)

        mock.verify()

      it "should not force switches if opponent is the last pokemon", ->
        shared.create.call(this, team2: [Factory("Magikarp")])

        mock = @sandbox.mock(@team2)
        mock.expects("switch").never()

        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)

        mock.verify()

      it "cancels the opponent's move if user moves first", ->
        shared.create.call this,
          team1: [ Factory("Magikarp", moves: [ moveName ], evs: {speed: 4}), Factory("Magikarp")]
          team2: [ Factory("Magikarp", moves: [ moveName ]), Factory("Magikarp")]

        spy1 = @sandbox.spy(@team1, 'switch')
        spy2 = @sandbox.spy(@team2, 'switch')
        @controller.makeMove(@id1, moveName)
        @controller.makeMove(@id2, moveName)
        spy1.callCount.should.equal(0)
        spy2.callCount.should.equal(1)

  testRandomSwitchMove "Roar"
  testRandomSwitchMove "Whirlwind"
  testRandomSwitchMove "Dragon Tail"
  testRandomSwitchMove "Circle Throw"

  testTrappingMove = (name) ->
    describe name, ->
      it "blocks switching", ->
        shared.create.call(this)

        @battle.performMove(@p1, @battle.getMove(name))
        @battle.endTurn()
        @battle.beginTurn()
        @p2.isSwitchBlocked().should.be.true
        @p2.has(Attachment.Trap).should.be.true
        @p1.has(Attachment.TrapLeash).should.be.true

      it "deals 1/16 of the pokemon's max hp every turn", ->
        shared.create.call(this, team2: [Factory("Blissey")])

        @battle.performMove(@p1, @battle.getMove(name))
        @p2.currentHP = @p2.stat('hp')
        @battle.endTurn()
        maxHP = @p2.stat('hp')
        expected = maxHP - Math.floor(maxHP / 16)
        @p2.currentHP.should.equal expected

      it "deals a minimum of 1 damage", ->
        shared.create.call(this, team2: [Factory("Shedinja")])
        @p2.types = [ "Normal" ]
        move = @battle.getMove(name)
        @sandbox.stub(move, 'calculateDamage', -> 0)

        @battle.performMove(@p1, move)
        @battle.endTurn()
        @p2.currentHP.should.equal(0)

      it "lasts several turns", ->
        shared.create.call(this, team2: [Factory("Blissey")])
        shared.biasRNG.call(this, "randInt", 'trapping move', 5)

        @battle.performMove(@p1, @battle.getMove(name))
        @p2.currentHP = @p2.stat('hp')

        # loop for 5 more turns. One of the turns has already passed.
        # These moves hurt for 5 moves and wear off on the 6th.
        for i in [1..5]
          @p2.has(Attachment.Trap).should.be.true
          @battle.endTurn()

        # Test if the actual damage checks out. It should have damaged only 5 times
        maxHP = @p2.stat('hp')
        expected = maxHP - (Math.floor(maxHP / 16) * 5)
        @p2.currentHP.should.equal expected

      it "wears off after a certain number of turns", ->
        shared.create.call(this, team2: [Factory("Blissey")])
        shared.biasRNG.call(this, "randInt", 'trapping move', 5)

        @battle.performMove(@p1, @battle.getMove(name))
        @battle.endTurn()

        # loop for 5 more turns. One of the turns has already passed.
        # These moves hurt for 5 moves and wear off on the 6th. We need
        # turn number 6 to pass before the attachment should wear off.
        for i in [1..5]
          @battle.endTurn()
          @battle.beginTurn()

        @p2.isSwitchBlocked().should.be.false
        @p2.has(Attachment.Trap).should.be.false
        @p1.has(Attachment.TrapLeash).should.be.false

      it "does not reset the duration if used twice", ->
        shared.create.call(this, team2: [Factory("Blissey")])
        shared.biasRNG.call(this, "randInt", 'trapping move', 5)

        @battle.performMove(@p1, @battle.getMove(name))
        @battle.endTurn()

        @battle.performMove(@p1, @battle.getMove(name))
        @battle.endTurn()

        # loop for 4 more turns. These moves wear off after numTurns + 1.
        # 2 have already passed.
        for i in [1..4]
          @battle.endTurn()
          @battle.beginTurn()

        @p2.isSwitchBlocked().should.be.false
        @p2.has(Attachment.Trap).should.be.false
        @p1.has(Attachment.TrapLeash).should.be.false

      it "wears off if the user switches", ->
        shared.create.call(this, team1: [Factory("Blissey"), Factory("Magikarp")])

        @battle.performMove(@p1, @battle.getMove(name))
        @battle.endTurn()

        @controller.makeSwitch(@id1, 1)
        @controller.makeMove(@id2, "Splash")

        @p2.isSwitchBlocked().should.be.false
        @p2.has(Attachment.Trap).should.be.false

      it "wears off if the user faints", ->
        shared.create.call(this, team1: [Factory("Heatran")],  team2: [Factory("Blissey")])
        @p1.currentHP = 1

        @battle.performMove(@p1, @battle.getMove(name))
        @battle.endTurn()
        @battle.beginTurn()

        @p2.isSwitchBlocked().should.be.true
        @p2.has(Attachment.Trap).should.be.true

        @battle.recordMove(@id2, @battle.getMove("Tackle"))

        @battle.continueTurn()
        @battle.endTurn()
        @battle.beginTurn()

        @p2.isSwitchBlocked().should.be.false
        @p2.has(Attachment.Trap).should.be.false

      it "properly removes from a list of attachments", ->
        shared.create.call(this, team1: [Factory("Blissey"), Factory("Magikarp")])

        @battle.performMove(@p1, @battle.getMove(name))
        @battle.endTurn()

        @battle.recordMove(@id1, @battle.getMove("Protect"))
        @battle.recordMove(@id2, @battle.getMove("Splash"))
        @battle.continueTurn()
        @battle.endTurn()
        @battle.beginTurn()

        @controller.makeSwitch(@id1, 1)
        @controller.makeMove(@id2, "Splash")

        @p2.isSwitchBlocked().should.be.false
        @p2.has(Attachment.Trap).should.be.false

      it "is always 7 turns if the user is holding grip claw", ->
        shared.create.call(this, team1: [Factory("Magikarp", item: "Grip Claw")])
        shared.biasRNG.call(this, "randInt", 'trapping move', 5)

        move = @battle.getMove(name)
        @battle.performMove(@p1, move)
        @battle.performMove(@p2, @battle.getMove("Recover"))

        # The user is damaged 7 times, but the attachment actually lasts
        # for 8 turns including the turn it is first used.
        for i in [1..8]
          @p2.has(Attachment.Trap).should.be.true
          @battle.endTurn()

        @p2.has(Attachment.Trap).should.be.false

      it "does not start the effect if it hits a substitute", ->
        shared.create.call(this, team2: [Factory("Blissey")])

        @p2.attach(Attachment.Substitute, hp: 1)
        @battle.performMove(@p1, @battle.getMove(name))
        @battle.endTurn()

        @p2.isSwitchBlocked().should.be.false
        @p2.has(Attachment.Trap).should.be.false
        @p1.has(Attachment.TrapLeash).should.be.false

  testTrappingMove "Bind"
  testTrappingMove "Clamp"
  testTrappingMove "Fire Spin"
  testTrappingMove "Magma Storm"
  testTrappingMove "Sand Tomb"
  testTrappingMove "Whirlpool"
  testTrappingMove "Wrap"

  describe "Attract", ->
    shared.shouldDoNoDamage('Attract')
    shared.shouldFailIfUsedTwice "Attract",
      team1: [Factory("Magikarp", gender: "M", evs: {speed: 4})]
      team2: [Factory("Magikarp", gender: "F")]

    it "has a 50% chance to immobilize a pokemon", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "M", evs: {speed: 4})]
        team2: [Factory("Magikarp", gender: "F")]
      shared.biasRNG.call(this, "next", 'attract chance', 0)  # 100% immobilizes

      mock = @sandbox.mock(@battle.getMove('Tackle')).expects('execute').never()
      @battle.performMove(@p1, @battle.getMove("Attract"))
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      mock.verify()

    it "has a 50% chance to not immobilize a pokemon", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "M", evs: {speed: 4})]
        team2: [Factory("Magikarp", gender: "F")]
      shared.biasRNG.call(this, "next", 'attract chance', .5)  # 0% immobilizes

      mock = @sandbox.mock(@battle.getMove('Tackle')).expects('execute').once()
      @battle.performMove(@p1, @battle.getMove("Attract"))
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      mock.verify()

    it "fails if the Pokemon are not opposite genders", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "F")]
        team2: [Factory("Magikarp", gender: "F")]

      mock = @sandbox.mock(@battle.getMove('Attract')).expects('fail').once()
      @battle.performMove(@p1, @battle.getMove("Attract"))
      mock.verify()

    it "disappears if the source is no longer active", ->
      shared.create.call this,
        team1: (Factory("Magikarp", gender: "M")  for x in [1..2])
        team2: [Factory("Magikarp", gender: "F")]
      @battle.performMove(@p1, @battle.getMove('Attract'))
      @battle.performMove(@p2, @battle.getMove('Splash'))
      @p2.has(Attachment.Attract).should.be.true
      @battle.performSwitch(@team1.first(), 1)
      @battle.performMove(@p2, @battle.getMove('Splash'))
      @p2.has(Attachment.Attract).should.be.false

  describe "Reflect", ->
    it "halves physical damage", ->
      shared.create.call(this)
      tackle = @battle.getMove('Tackle')
      tackle.modifyDamage(@battle, @p1, @p2).should.equal(0x1000)

      @team2.attach(Attachment.Reflect)
      tackle.modifyDamage(@battle, @p1, @p2).should.equal(0x800)

    it "does not halve non-physical damage", ->
      shared.create.call(this)
      thundershock = @battle.getMove('ThunderShock')
      thundershock.modifyDamage(@battle, @p1, @p2).should.equal(0x1000)

      @team2.attach(Attachment.Reflect)
      thundershock.modifyDamage(@battle, @p1, @p2).should.equal(0x1000)

    it "lasts five turns", ->
      shared.create.call(this)

      @battle.performMove(@p1, @battle.getMove('Reflect'))

      for i in [1..5]
        @team1.has(Attachment.Reflect).should.be.true
        @battle.endTurn()
      @team1.has(Attachment.Reflect).should.be.false

    it "fails if the user already used it", ->
      shared.create.call(this)
      mock = @sandbox.mock(@battle.getMove('Reflect'))
      mock.expects('fail').once()

      @battle.performMove(@p1, @battle.getMove('Reflect'))
      @battle.performMove(@p1, @battle.getMove('Reflect'))

      mock.verify()

    it "does not halve on critical hits", ->
      shared.create.call(this)
      tackle = @battle.getMove('Tackle')
      @team2.attach(Attachment.Reflect)
      @p1.crit = true
      tackle.modifyDamage(@battle, @p1, @p2).should.equal(0x1000)

  describe "Light Screen", ->
    it "halves special damage", ->
      shared.create.call(this)
      thundershock = @battle.getMove('ThunderShock')
      thundershock.modifyDamage(@battle, @p1, @p2).should.equal(0x1000)

      @team2.attach(Attachment.LightScreen)
      thundershock.modifyDamage(@battle, @p1, @p2).should.equal(0x800)

    it "does not halve non-physical damage", ->
      shared.create.call(this)
      tackle = @battle.getMove('Tackle')
      tackle.modifyDamage(@battle, @p1, @p2).should.equal(0x1000)

      @team2.attach(Attachment.LightScreen)
      tackle.modifyDamage(@battle, @p1, @p2).should.equal(0x1000)

    it "lasts five turns", ->
      shared.create.call(this)

      @battle.performMove(@p1, @battle.getMove('Light Screen'))

      for i in [1..5]
        @team1.has(Attachment.LightScreen).should.be.true
        @battle.endTurn()
      @team1.has(Attachment.LightScreen).should.be.false

    it "fails if the user already used it", ->
      shared.create.call(this)
      mock = @sandbox.mock(@battle.getMove('Light Screen'))
      mock.expects('fail').once()

      @battle.performMove(@p1, @battle.getMove('Light Screen'))
      @battle.performMove(@p1, @battle.getMove('Light Screen'))

      mock.verify()

    it "does not halve on critical hits", ->
      shared.create.call(this)
      thundershock = @battle.getMove('ThunderShock')
      @team2.attach(Attachment.LightScreen)
      @p1.crit = true
      thundershock.modifyDamage(@battle, @p1, @p2).should.equal(0x1000)

  describe "Rapid Spin", ->
    it "removes spikes", ->
      shared.create.call this

      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @team2.has(Attachment.Spikes).should.be.true

      @battle.performMove(@p2, @battle.getMove("Rapid Spin"))
      @team2.has(Attachment.Spikes).should.be.false

    it "removes stealth rock", ->
      shared.create.call this

      @battle.performMove(@p1, @battle.getMove("Stealth Rock"))
      @team2.has(Attachment.StealthRock).should.be.true

      @battle.performMove(@p2, @battle.getMove("Rapid Spin"))
      @team2.has(Attachment.StealthRock).should.be.false

    it "removes toxic spikes", ->
      shared.create.call this

      @battle.performMove(@p1, @battle.getMove("Toxic Spikes"))
      @team2.has(Attachment.ToxicSpikes).should.be.true

      @battle.performMove(@p2, @battle.getMove("Rapid Spin"))
      @team2.has(Attachment.ToxicSpikes).should.be.false

    it "removes multiple layers of entry hazards", ->
      shared.create.call this

      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @team2.has(Attachment.Spikes).should.be.true

      @battle.performMove(@p2, @battle.getMove("Rapid Spin"))
      @team2.has(Attachment.Spikes).should.be.false

    it "removes trapping moves", ->
      shared.create.call this

      @battle.performMove(@p1, @battle.getMove("Fire Spin"))

      @p2.has(Attachment.Trap).should.be.true
      @p1.has(Attachment.TrapLeash).should.be.true
      @battle.performMove(@p2, @battle.getMove("Rapid Spin"))
      @p2.has(Attachment.Trap).should.be.false
      @p1.has(Attachment.TrapLeash).should.be.false

    it "removes leech seed", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Leech Seed"))
      @p2.has(Attachment.LeechSeed).should.be.true
      @battle.performMove(@p2, @battle.getMove("Rapid Spin"))
      @p2.has(Attachment.LeechSeed).should.be.false

    it "does not remove entry hazards if the user faints from rough skin", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Rough Skin")])

      @p2.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @battle.performMove(@p2, @battle.getMove("Rapid Spin"))

      @team2.has(Attachment.Spikes).should.be.true

    it "does remove entry hazards if the user faints from life orb", ->
      shared.create.call(this, team2: [Factory("Magikarp", item: "Life Orb")])

      @p2.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @battle.performMove(@p2, @battle.getMove("Rapid Spin"))

      @team2.has(Attachment.Spikes).should.be.false

  describe "Brick Break", ->
    it "shatters Light Screen", ->
      shared.create.call(this)
      @team2.attach(Attachment.LightScreen)
      @battle.performMove(@p1, @battle.getMove('Brick Break'))
      @team2.has(Attachment.LightScreen).should.be.false

    it "shatters Reflect", ->
      shared.create.call(this)
      @team2.attach(Attachment.Reflect)
      @battle.performMove(@p1, @battle.getMove('Brick Break'))
      @team2.has(Attachment.Reflect).should.be.false

    it "shatters both at the same time", ->
      shared.create.call(this)
      @team2.attach(Attachment.Reflect)
      @team2.attach(Attachment.LightScreen)
      @battle.performMove(@p1, @battle.getMove('Brick Break'))
      @team2.has(Attachment.Reflect).should.be.false
      @team2.has(Attachment.LightScreen).should.be.false

    it "shatters before damage calculation", ->
      shared.create.call(this)
      move = @battle.getMove("Brick Break")
      damage = move.calculateDamage(@battle, @p1, @p2)
      @team2.attach(Attachment.Reflect)
      @team2.attach(Attachment.LightScreen)

      spy = @sandbox.spy(move, 'calculateDamage')
      @battle.performMove(@p1, move)
      spy.returned(damage).should.be.true

    it "does not shatter if the target is immune", ->
      shared.create.call(this)
      @team2.attach(Attachment.Reflect)
      @team2.attach(Attachment.LightScreen)

      @sandbox.stub(@p2, 'isImmune', -> true)
      @battle.performMove(@p1, @battle.getMove('Brick Break'))
      @team2.has(Attachment.Reflect).should.be.true
      @team2.has(Attachment.LightScreen).should.be.true

    it "does not shatter if Brick Break misses", ->
      shared.create.call(this)
      @team2.attach(Attachment.Reflect)
      @team2.attach(Attachment.LightScreen)

      shared.biasRNG.call(this, 'randInt', 'miss', 101)
      @battle.performMove(@p1, @battle.getMove('Brick Break'))
      @team2.has(Attachment.Reflect).should.be.true
      @team2.has(Attachment.LightScreen).should.be.true

  describe "Return", ->
    it "has 102 base power", ->
      shared.create.call(this)
      move = @battle.getMove("Return")
      bp = move.basePower(@battle, @p1, @p2)
      bp.should.equal 102

  describe "Frustration", ->
    it "has 102 base power", ->
      shared.create.call(this)
      move = @battle.getMove("Frustration")
      bp = move.basePower(@battle, @p1, @p2)
      bp.should.equal 102

  describe "Fake Out", ->
    it "flinches the enemy", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Fake Out"))
      @p2.has(Attachment.Flinch).should.be.true

    it "fails if the Pokemon has been in play one turn or more", ->
      shared.create.call(this)
      @battle.endTurn()
      @battle.beginTurn()
      fakeOut = @battle.getMove("Fake Out")
      mock = @sandbox.mock(fakeOut).expects('fail').once()
      @battle.performMove(@p1, fakeOut)
      mock.verify()

    it "works if the Pokemon is newly switched", ->
      shared.create.call(this, team1: (Factory("Magikarp")  for x in [1..2]))
      @battle.performSwitch(@team1.first(), 1)
      @battle.endTurn()
      @battle.beginTurn()
      fakeOut = @battle.getMove("Fake Out")
      mock = @sandbox.mock(fakeOut).expects('fail').never()
      @battle.performMove(@team1.first(), fakeOut)
      mock.verify()

  describe "Focus Energy", ->
    it "adds a Focus Energy attachment to the user", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Focus Energy"))
      @p1.has(Attachment.FocusEnergy).should.be.true

    it "fails the second time it is used", ->
      shared.create.call(this)
      move = @battle.getMove("Focus Energy")
      mock = @sandbox.mock(move)
      mock.expects('fail').once()

      @battle.performMove(@p1, move)
      @battle.performMove(@p1, move)

      mock.verify()

  testIdentifyMove = (moveName, types) ->
    describe moveName, ->
      shared.shouldDoNoDamage(moveName)
      shared.shouldFailIfUsedTwice(moveName)

      it "makes the target vulnerable to #{types} moves", ->
        shared.create.call(this, team2: [Factory("Spiritomb")])
        _.each(types, ((type) -> @isImmune(type).should.be.true), @p2)
        @battle.performMove(@p1, @battle.getMove(moveName))
        @p2.has(Attachment.Identify).should.be.true
        _.each(types, ((type) -> @isImmune(type).should.be.false), @p2)

      it "makes the target's evasion be ignored", ->
        shared.create.call(this)
        @p2.boost(evasion: 2)
        @p2.editBoosts().evasion.should.equal 2
        @battle.performMove(@p1, @battle.getMove(moveName))
        @p2.editBoosts().evasion.should.equal 0

  testIdentifyMove("Foresight", ["Normal", "Fighting"])
  testIdentifyMove("Odor Sleuth", ["Normal", "Fighting"])
  testIdentifyMove("Miracle Eye", ["Psychic"])

  describe "Conversion", ->
    it "changes the user's type to a random type based on moves", ->
      shared.create.call this,
        team1: [Factory("Porygon", moves: [
          "Thunderbolt", "Ice Beam", "Conversion" ])]
      shared.biasRNG.call(this, "randInt", 'conversion types', 0)
      @p1.types.should.eql [ "Normal" ]
      @battle.performMove(@p1, @battle.getMove("Conversion"))
      @p1.types.should.eql [ 'Electric' ]

    it "ignores Conversion as part of the move types", ->
      shared.create.call this,
        team1: [Factory("Porygon", moves: [ "Conversion", "Ice Beam" ])]
      shared.biasRNG.call(this, "randInt", 'conversion types', 0)
      @p1.types = [ "Fake Type" ]
      @battle.performMove(@p1, @battle.getMove("Conversion"))
      @p1.types.should.eql [ 'Ice' ]

    it "fails if there is no type to convert to", ->
      shared.create.call this,
        team1: [Factory("Porygon", moves: [ "Conversion" ])]
      move = @battle.getMove("Conversion")
      mock = @sandbox.mock(move)
      mock.expects('fail').once()

      @battle.performMove(@p1, move)
      mock.verify()

  describe "Conversion 2", ->
    it "fails if the target has not yet moved", ->
      shared.create.call(this)
      move = @battle.getMove("Conversion 2")
      mock = @sandbox.mock(move).expects('fail').once()

      @p2.lastMove = null
      @battle.performMove(@p1, move)
      mock.verify()

    it "changes user's type to one resisting or is immune to target's move", ->
      shared.create.call(this)
      @p1.types = [ "Normal" ]

      move = @battle.getMove("Ember")
      type = move.type
      @p2.lastMove = move
      @battle.performMove(@p1, @battle.getMove("Conversion 2"))
      @p1.types.should.have.length 1
      util.typeEffectiveness(type, @p1.types).should.be.lessThan 1

  describe "Defense Curl", ->
    it "raises defense by 1 stage", ->
      shared.create.call(this)
      @p1.stages.defense.should.equal 0
      @battle.performMove(@p1, @battle.getMove("Defense Curl"))
      @p1.stages.defense.should.equal 1

    it "attaches a volatile attachment", ->
      shared.create.call(this)
      @p1.has(Attachment.DefenseCurl).should.be.false
      @battle.performMove(@p1, @battle.getMove("Defense Curl"))
      @p1.has(Attachment.DefenseCurl).should.be.true

  describe "Focus Punch", ->
    it "causes the user to flinch if hit", ->
      shared.create.call(this)
      @battle.recordMove(@id1, @battle.getMove("Focus Punch"))
      @battle.recordMove(@id2, @battle.getMove("Tackle"))
      @battle.continueTurn()
      @p2.currentHP.should.not.be.lessThan @p2.stat('hp')

    it "does not cause flinching if hit by a non-damaging move", ->
      shared.create.call(this)
      @battle.recordMove(@id1, @battle.getMove("Focus Punch"))
      @battle.recordMove(@id2, @battle.getMove("Will-O-Wisp"))
      @battle.continueTurn()
      @p2.currentHP.should.be.lessThan @p2.stat('hp')

    it "does not cause flinching if behind a substitute", ->
      shared.create.call(this)
      @p1.attach(Attachment.Substitute, hp: (@p1.currentHP >> 2))
      @battle.recordMove(@id1, @battle.getMove("Focus Punch"))
      @battle.recordMove(@id2, @battle.getMove("Tackle"))
      @battle.continueTurn()
      @p2.currentHP.should.be.lessThan @p2.stat('hp')

    it "does not cause flinching if sub fades", ->
      shared.create.call(this)
      @p1.attach(Attachment.Substitute, hp: 1)
      @battle.recordMove(@id1, @battle.getMove("Focus Punch"))
      @battle.recordMove(@id2, @battle.getMove("Tackle"))
      @battle.continueTurn()
      @p2.currentHP.should.be.lessThan @p2.stat('hp')

    it "does not cause flinching if hit by a move last turn", ->
      shared.create.call(this)
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @battle.endTurn()
      @battle.beginTurn()
      @battle.recordMove(@id1, @battle.getMove("Focus Punch"))
      @battle.continueTurn()
      @p2.currentHP.should.be.lessThan @p2.stat('hp')

    it "does not cause flinching afterwards", ->
      shared.create.call(this, team2: [Factory("Magikarp", evs: {speed: 4})])
      focusPunch = @battle.getMove("Focus Punch")
      @battle.recordMove(@id1, @battle.getMove("Focus Punch"))
      @battle.recordMove(@id2, @battle.getMove("Splash"))
      @battle.continueTurn()
      @battle.endTurn()
      @battle.beginTurn()

      hp = @p2.currentHP
      @battle.recordMove(@id1, @battle.getMove("Tackle"))
      @battle.recordMove(@id2, @battle.getMove("Tackle"))
      @battle.continueTurn()
      @p2.currentHP.should.be.lessThan(hp)

  describe "Magnet Rise", ->
    shared.shouldDoNoDamage("Magnet Rise")
    shared.shouldFailIfUsedTwice("Magnet Rise")

    it "makes the user immune to ground moves", ->
      shared.create.call(this)
      @p1.isImmune("Ground").should.be.false
      @battle.performMove(@p1, @battle.getMove("Magnet Rise"))
      @p1.isImmune("Ground").should.be.true

    it "lasts 5 turns", ->
      shared.create.call(this)
      @p1.isImmune("Ground").should.be.false
      @battle.performMove(@p1, @battle.getMove("Magnet Rise"))
      for i in [1..5]
        @p1.isImmune("Ground").should.be.true
        @battle.endTurn()
      @p1.isImmune("Ground").should.be.false

  testLockOnMove = (moveName) ->
    describe moveName, ->
      shared.shouldDoNoDamage(moveName)
      shared.shouldFailIfUsedTwice(moveName)

      it "makes the user's next move never miss on this target", ->
        shared.create.call(this)
        shared.biasRNG.call(this, 'randInt', 'miss', 101)
        @battle.performMove(@p1, @battle.getMove(moveName))
        missMove = @battle.getMove("Tackle")
        missMove.willMiss(@battle, @p1, @p2)
          .should.be.false

      it "lasts only two turns", ->
        shared.create.call(this)
        @battle.performMove(@p1, @battle.getMove(moveName))
        for i in [1..2]
          @p1.has(Attachment.LockOn).should.be.true
          @battle.endTurn()
        @p1.has(Attachment.LockOn).should.be.false

      it "hits through two-turn fade-away moves"
      it "does not hit through Protect"
      it "does not affect accuracy on another target"
      it "re-locks on when used on another target"

  testLockOnMove("Lock-On")
  testLockOnMove("Mind Reader")

  describe "Minimize", ->
    it "boosts the user's evasion by 2", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Minimize"))
      @p1.stages.evasion.should.equal 2

    it "adds a Minimize volatile attachment to the user", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Minimize"))
      @p1.has(Attachment.Minimize).should.be.true

  testStompMove = (moveName) ->
    describe moveName, ->
      it "doubles its base power when the target is minimized", ->
        shared.create.call(this)
        @p2.attach(Attachment.Minimize)
        move = @battle.getMove(moveName)
        bp = move.basePower(@battle, @p1, @p2)
        bp.should.equal(move.power * 2)

      it "has normal base power otherwise", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)
        bp = move.basePower(@battle, @p1, @p2)
        bp.should.equal(move.power)

      it "has a 30% chance to flinch", ->
        shared.create.call(this)
        shared.biasRNG.call(this, 'randInt', 'flinch', 0)  # 100% chance
        @battle.performMove(@p1, @battle.getMove(moveName))
        @p2.has(Attachment.Flinch).should.be.true

  testStompMove("Stomp")
  testStompMove("Steamroller")

  testMeanLookMove = (moveName) ->
    describe moveName, ->
      shared.shouldDoNoDamage(moveName)
      shared.shouldFailIfUsedTwice(moveName)

      it "blocks the target from switching", ->
        shared.create.call(this)
        @p2.isSwitchBlocked().should.be.false

        @battle.performMove(@p1, @battle.getMove(moveName))
        @battle.beginTurn()
        @p2.isSwitchBlocked().should.be.true

      it "wears off if the user faints", ->
        shared.create.call(this)
        @p1.currentHP = 1

        @battle.performMove(@p1, @battle.getMove(moveName))
        @battle.endTurn()
        @battle.beginTurn()

        @p2.isSwitchBlocked().should.be.true
        @p2.has(Attachment.MeanLook).should.be.true

        @battle.recordMove(@id2, @battle.getMove("Tackle"))

        @battle.continueTurn()
        @battle.endTurn()
        @battle.beginTurn()

        @p2.isSwitchBlocked().should.be.false
        @p2.has(Attachment.MeanLook).should.be.false

      it "wears off if the user switches", ->
        shared.create.call(this, team1: [Factory("Blissey"), Factory("Magikarp")])

        @battle.performMove(@p1, @battle.getMove(moveName))
        @battle.endTurn()

        @controller.makeSwitch(@id1, 1)
        @controller.makeMove(@id2, "Splash")

        @p2.isSwitchBlocked().should.be.false
        @p2.has(Attachment.MeanLook).should.be.false

  testMeanLookMove("Block")
  testMeanLookMove("Mean Look")
  testMeanLookMove("Spider Web")

  testRechargeMove = (moveName) ->
    describe moveName, ->
      it "blocks the target from switching the next turn", ->
        shared.create.call(this)
        @p1.isSwitchBlocked().should.be.false

        theMove = @battle.getMove(moveName)
        @sandbox.stub(theMove, 'baseDamage', -> 2)
        @battle.performMove(@p1, theMove)
        @battle.endTurn()
        @battle.beginTurn()
        @p1.isSwitchBlocked().should.be.true

      it "blocks the target from picking a new move the next turn", ->
        shared.create.call(this)

        theMove = @battle.getMove(moveName)
        @sandbox.stub(theMove, 'baseDamage', -> 2)
        @battle.performMove(@p1, theMove)
        @battle.endTurn()
        @battle.beginTurn()
        for move in @p1.moves
          @p1.isMoveBlocked(move).should.be.true

      it "automatically selects a special recharge move the next turn", ->
        shared.create.call(this)
        specialMove = @battle.getMove("Recharge")

        theMove = @battle.getMove(moveName)
        @sandbox.stub(theMove, 'baseDamage', -> 2)
        @battle.performMove(@p1, theMove)
        @battle.endTurn()
        @battle.beginTurn()

        @battle.requests.should.not.have.property @id1
        action = @battle.getAction(@p1)
        should.exist(action)
        action.should.have.property("move")
        action.move.should.equal(specialMove)

      it "prevents the user from moving the next turn", ->
        shared.create.call(this)

        spy = @sandbox.spy(@p1, 'beforeMove')
        theMove = @battle.getMove(moveName)
        @sandbox.stub(theMove, 'baseDamage', -> 2)
        @battle.performMove(@p1, theMove)
        @battle.endTurn()
        @battle.beginTurn()
        @battle.continueTurn()
        spy.returned(false).should.be.true

  testRechargeMove("Hyper Beam")
  testRechargeMove("Giga Impact")
  testRechargeMove("Blast Burn")
  testRechargeMove("Frenzy Plant")
  testRechargeMove("Hydro Cannon")
  testRechargeMove("Roar of Time")
  testRechargeMove("Rock Wrecker")

  describe 'Clear Smog', ->
    it 'removes all status boosts on the target pokemon', ->
      shared.create.call(this)
      # Create artificial boosts.
      @p2.stages.defense = -3
      @p2.stages.specialAttack = 4
      @battle.performMove(@p1, @battle.getMove("Clear Smog"))
      neutralBoosts = {
        attack: 0, defense: 0, specialAttack: 0, specialDefense: 0,
        speed: 0, evasion: 0, accuracy: 0
      }
      @p2.stages.should.eql neutralBoosts

    it "does not reset stats if it hits a substitute", ->
      shared.create.call(this)
      @p2.attach(Attachment.Substitute, hp: 1)
      # Create artificial boosts.
      @p2.stages.defense = -3
      @p2.stages.specialAttack = 4
      @battle.performMove(@p1, @battle.getMove("Clear Smog"))
      neutralBoosts = {
        attack: 0, defense: 0, specialAttack: 0, specialDefense: 0,
        speed: 0, evasion: 0, accuracy: 0
      }
      @p2.stages.should.not.eql neutralBoosts

  testMomentumMove = (moveName) ->
    describe moveName, ->
      it "prevents the user from switching", ->
        shared.create.call(this)
        @p1.isSwitchBlocked().should.be.false

        @battle.performMove(@p1, @battle.getMove(moveName))
        @battle.endTurn()
        @battle.beginTurn()
        @p1.isSwitchBlocked().should.be.true

      it "locks the user into using this particular move", ->
        shared.create.call this,
          team1: [ Factory("Shuckle") ]

        momentumMove = @battle.getMove(moveName)
        @p1.moves = [ momentumMove, @battle.getMove("Rest") ]
        @p1.resetAllPP()

        @battle.performMove(@p1, momentumMove)
        @battle.endTurn()
        @battle.beginTurn()
        for move in @p1.moves
          if move == momentumMove
            @p1.isMoveBlocked(move).should.be.false
          else
            @p1.isMoveBlocked(move).should.be.true

      it "stops if it misses", ->
        shared.create.call(this)
        shared.biasRNG.call(this, "randInt", 'miss', 100)

        @battle.performMove(@p1, @battle.getMove(moveName))
        @battle.endTurn()
        @battle.beginTurn()
        @p1.has(Attachment.Momentum).should.be.false

      it "lasts 5 turns", ->
        shared.create.call(this)

        for i in [1..5]
          @battle.performMove(@p1, @battle.getMove(moveName))
          @p1.has(Attachment.Momentum).should.be.true
          @battle.endTurn()
          @battle.beginTurn()
        @p1.has(Attachment.Momentum).should.be.false

      it "doubles base power every time", ->
        shared.create.call(this)

        move = @battle.getMove(moveName)
        basePower = move.power
        for i in [1..5]
          bp = move.basePower(@battle, @p1, @p2)
          bp.should.equal(basePower * Math.pow(2, i - 1))
          @battle.performMove(@p1, move)
          @battle.endTurn()
          @battle.beginTurn()
          @p2.currentHP = @p2.stat('hp')

      it "doubles base power again if user has defense curl's effect", ->
        shared.create.call(this)

        @p1.attach(Attachment.DefenseCurl)

        move = @battle.getMove(moveName)
        basePower = 2 * move.power
        for i in [1..5]
          bp = move.basePower(@battle, @p1, @p2)
          bp.should.equal(basePower * Math.pow(2, i - 1))
          @battle.performMove(@p1, move)
          @battle.endTurn()
          @battle.beginTurn()
          @p2.currentHP = @p2.stat('hp')

  testMomentumMove("Rollout")
  testMomentumMove("Ice Ball")

  describe "Me First", ->
    it "fails if the user goes second", ->
      shared.create.call(this)

      move = @battle.getMove("Me First")
      mock = @sandbox.mock(move).expects('fail').once()

      @battle.recordMove(@id1, move)
      @battle.recordMove(@id2, @battle.getMove("Tackle"))
      @battle.determineTurnOrder()
      @battle.delay @p1
      @battle.popAction(@p2)
      @battle.performMove(@p1, move)

      mock.verify()

    it "uses the target's move", ->
      shared.create.call(this)

      move = @battle.getMove("Tackle")
      mock = @sandbox.mock(move).expects('execute').once()

      @battle.recordMove(@id1, @battle.getMove("Me First"))
      @battle.recordMove(@id2, move)
      @battle.determineTurnOrder()
      @battle.bump @p1
      @battle.performMove(@p1, @battle.getMove("Me First"))

      mock.verify()

    it "has 1.5x the base power of the target's move", ->
      shared.create.call(this)

      move = @battle.getMove("Tackle")

      @battle.recordMove(@id1, @battle.getMove("Me First"))
      @battle.recordMove(@id2, move)
      @battle.determineTurnOrder()
      @battle.bump @p1
      @battle.performMove(@p1, @battle.getMove("Me First"))

      move.modifyAttack(@battle, @p1, @p2).should.equal 0x1800

    for moveName in [ "Chatter", "Counter", "Covet", "Focus Punch", "Me First",
                      "Metal Burst", "Mirror Coat", "Struggle", "Thief" ]
      do (moveName) ->
        it "fails if the target is using #{moveName}", ->
          shared.create.call(this)

          move = @battle.getMove("Me First")
          mock = @sandbox.mock(move).expects('fail').once()

          @battle.recordMove(@id1, move)
          @battle.recordMove(@id2, @battle.getMove(moveName))
          @battle.determineTurnOrder()
          @battle.bump @p1
          @battle.performMove(@p1, move)

          mock.verify()

    it "fails if the target is using a non-damaging move", ->
      shared.create.call(this)

      move = @battle.getMove("Me First")
      mock = @sandbox.mock(move).expects('fail').once()

      @battle.recordMove(@id1, move)
      @battle.recordMove(@id2, @battle.getMove("Splash"))
      @battle.determineTurnOrder()
      @battle.bump @p1
      @battle.performMove(@p1, move)

      mock.verify()

  describe "Dream Eater", ->
    it "fails if the target is not asleep", ->
      shared.create.call(this)
      move = @battle.getMove("Dream Eater")
      mock = @sandbox.mock(move).expects('fail').once()

      @battle.performMove(@p1, move)

      mock.verify()

    it "does not fail if the target is asleep", ->
      shared.create.call(this)
      move = @battle.getMove("Dream Eater")
      mock = @sandbox.mock(move).expects('fail').never()

      @p2.attach(Status.Sleep)
      @battle.performMove(@p1, move)

      mock.verify()

    it "drains 1/2 of damage", ->
      shared.create.call(this)
      @p1.currentHP = initialHP = 1

      @p2.attach(Status.Sleep)
      @battle.performMove(@p1, @battle.getMove("Dream Eater"))

      damage = @p2.stat('hp') - @p2.currentHP
      healed = Math.floor(damage / 2)
      @p1.currentHP.should.equal(initialHP + healed)

  describe "Camouflage", ->
    it "changes the user's type to Ground type in Wi-Fi battles", ->
      shared.create.call(this)

      @p1.types = [ "Normal" ]
      @battle.performMove(@p1, @battle.getMove("Camouflage"))
      @p1.types.should.eql [ "Ground" ]

  describe "Charge", ->
    shared.shouldDoNoDamage("Charge")
    it "raises the user's special defense by 1", ->
      shared.create.call(this)

      @p1.stages.specialDefense.should.equal 0
      @battle.performMove(@p1, @battle.getMove("Charge"))
      @p1.stages.specialDefense.should.equal 1

    it "doubles the base power of the user's next move", ->
      shared.create.call(this)
      move = @battle.getMove("Thunderbolt")

      move.modifyAttack(@battle, @p1, @p2).should.equal 0x1000
      @battle.performMove(@p1, @battle.getMove("Charge"))
      move.modifyAttack(@battle, @p1, @p2).should.equal 0x2000

    it "doesn't double the next move if it is non-electric type", ->
      shared.create.call(this)
      move = @battle.getMove("Flamethrower")

      move.modifyAttack(@battle, @p1, @p2).should.equal 0x1000
      @battle.performMove(@p1, @battle.getMove("Charge"))
      move.modifyAttack(@battle, @p1, @p2).should.equal 0x1000

    it "can be used twice in a row", ->
      shared.create.call(this)
      move = @battle.getMove("Charge")
      mock = @sandbox.mock(move).expects('fail').never()

      @battle.performMove(@p1, move)
      @battle.endTurn()
      @battle.performMove(@p1, move)
      @battle.endTurn()

      @p1.has(Attachment.Charge).should.be.true
      mock.verify()

  describe "Tri Attack", ->
    it "has a 20% chance to activate its secondary effect", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", 'secondary effect', 0)  # 100% chance
      @battle.performMove(@p1, @battle.getMove("Tri Attack"))
      @p2.hasStatus().should.be.true

    it "has a 1/3 chance for the secondary effect to be paralysis", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", 'secondary effect', 0)  # 100% chance
      shared.biasRNG.call(this, "randInt", 'tri attack effect', 0)  # par
      @battle.performMove(@p1, @battle.getMove("Tri Attack"))
      @p2.has(Status.Paralyze).should.be.true

    it "has a 1/3 chance for the secondary effect to be burn", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", 'secondary effect', 0)  # 100% chance
      shared.biasRNG.call(this, "randInt", 'tri attack effect', 1)  # brn
      @battle.performMove(@p1, @battle.getMove("Tri Attack"))
      @p2.has(Status.Burn).should.be.true

    it "has a 1/3 chance for the secondary effect to be freeze", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", 'secondary effect', 0)  # 100% chance
      shared.biasRNG.call(this, "randInt", 'tri attack effect', 2)  # frz
      @battle.performMove(@p1, @battle.getMove("Tri Attack"))
      @p2.has(Status.Freeze).should.be.true

  describe "Mirror Move", ->
    it "copies the opponent's last move", ->
      shared.create.call(this)
      move = @battle.getMove("Tackle")
      mock = @sandbox.mock(move).expects('execute').once()
      @p2.lastMove = move

      @battle.performMove(@p1, @battle.getMove("Mirror Move"))
      mock.verify()

    it "fails if the opponent has not moved the past turn", ->
      shared.create.call(this)
      move = @battle.getMove("Mirror Move")
      mock = @sandbox.mock(move).expects('fail').once()

      @battle.performMove(@p1, move)
      mock.verify()

    it "fails if the move does not have a `mirror` flag", ->
      shared.create.call(this)
      @p2.lastMove = @battle.getMove("Dragon Dance")
      move = @battle.getMove("Mirror Move")
      mock = @sandbox.mock(move).expects('fail').once()

      @battle.performMove(@p1, move)
      mock.verify()

    # TODO: Find out if this is true: when is lastMove nullified?
    it "fails if the pokemon was unable to move the previous turn"

  describe "Leech Seed", ->
    shared.shouldFailIfUsedTwice("Leech Seed")

    it "saps 1/8 of the target's max HP each turn", ->
      shared.create.call(this)
      move = @battle.getMove("Leech Seed")

      @p1.currentHP = 1
      @battle.performMove(@p1, move)
      @battle.endTurn()

      p = @p2
      fullHP = p.stat('hp')
      (fullHP - p.currentHP).should.equal Math.floor(fullHP / 8)
      @p1.currentHP.should.equal(fullHP - p.currentHP + 1)

    it "saps up to 1/8 HP", ->
      shared.create.call(this)
      move = @battle.getMove("Leech Seed")

      @p1.currentHP = 1
      @p2.currentHP = 1
      @battle.performMove(@p1, move)
      @battle.endTurn()

      @p1.currentHP.should.equal 2

    it "saps a minimum of 1 damage", ->
      shared.create.call(this, team2: [Factory("Shedinja")])
      move = @battle.getMove("Leech Seed")

      @battle.performMove(@p1, move)
      @battle.endTurn()

      @p2.currentHP.should.equal(0)

    it "always misses on Grass type Pokemon", ->
      shared.create.call(this)
      move = @battle.getMove("Leech Seed")
      mock = @sandbox.mock(move).expects('afterMiss').once()
      @p2.types = [ "Water", "Grass"]

      @battle.performMove(@p1, move)
      mock.verify()

    it "does not trigger if the user has fainted", ->
      shared.create.call(this, team1: (Factory("Magikarp") for x in [1..2]))
      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Leech Seed"))
      @p1.faint()
      @battle.endTurn()
      @p2.currentHP.should.equal @p2.stat('hp')

    it "leeches next pokemon to switch in at that slot", ->
      shared.create.call(this, team1: (Factory("Magikarp") for x in [1..2]))
      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Leech Seed"))
      @p1.faint()
      @battle.endTurn()
      @battle.performSwitch(@team1.first(), 1)
      @p2.currentHP.should.equal @p2.stat('hp')

      newFirst = @team1.first()
      newFirst.currentHP = 1
      @battle.endTurn()
      hp = @p2.stat('hp') - @p2.currentHP
      hp.should.be.greaterThan(0)
      newFirst.currentHP.should.equal(hp + 1)

    it "stops if the target has fainted", ->
      shared.create.call(this, team2: (Factory("Magikarp") for x in [1..2]))
      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Leech Seed"))
      @p2.faint()
      @battle.endTurn()
      @battle.performSwitch(@team2.first(), 1)
      @team2.first().currentHP.should.equal @team2.first().stat('hp')
      @p1.currentHP.should.equal(1)

  testProtectCounterMove = (moveName) ->
    it "fails if the user moves last this turn", ->
      shared.create.call(this)
      move = @battle.getMove(moveName)
      mock = @sandbox.mock(move).expects('fail').once()

      @battle.determineTurnOrder()
      @battle.performMove(@p1, move)
      mock.verify()

    it "has decreasing chances of success", ->
      shared.create.call(this)
      p = @p1

      for x in [0..7]
        attachment = p.attach(Attachment.ProtectCounter)
        attachment.successChance().should.equal Math.pow(2, x)

      attachment = p.attach(Attachment.ProtectCounter)
      attachment.successChance().should.equal Math.pow(2, 32)

    it "fails if not successful", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "randInt", 'protect', 2)
      move = @battle.getMove(moveName)
      mock = @sandbox.mock(move).expects('fail').once()

      @battle.recordMove(@id2, @battle.getMove("Tackle"))
      @battle.determineTurnOrder()
      @battle.performMove(@p1, move)
      mock.verify()

    it "resets to 100% chance of success if move fails", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "randInt", 'protect', 2)
      move = @battle.getMove(moveName)

      @battle.recordMove(@id2, @battle.getMove("Tackle"))
      @battle.determineTurnOrder()
      @battle.performMove(@p1, move)
      @p1.has(Attachment.ProtectCounter).should.be.false

    it "resets to 100% chance of success if user selects a different move", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "randInt", 'protect', 1)
      move = @battle.getMove(moveName)

      @battle.recordMove(@id2, @battle.getMove("Tackle"))
      @battle.determineTurnOrder()
      @battle.performMove(@p1, move)
      @battle.endTurn()
      @p1.has(Attachment.ProtectCounter).should.be.true

      @battle.performMove(@p1, @battle.getMove('Splash'))
      @battle.endTurn()

      @p1.has(Attachment.ProtectCounter).should.be.false

  testProtectMove = (moveName) ->
    describe moveName, ->
      testProtectCounterMove(moveName)

      it "completely protects the user from attacks", ->
        shared.create.call(this)
        move = @battle.getMove("Tackle")
        mock = @sandbox.mock(move).expects('hit').never()

        @battle.recordMove(@id2, move)
        @battle.determineTurnOrder()
        @battle.performMove(@p1, @battle.getMove(moveName))
        @battle.performMove(@p2, move)
        mock.verify()

      it "does not carry over to the next turn", ->
        shared.create.call(this)
        move = @battle.getMove("Tackle")

        @battle.recordMove(@id2, move)
        @battle.determineTurnOrder()
        @battle.performMove(@p1, @battle.getMove(moveName))
        @battle.performMove(@p2, move)
        @battle.endTurn()

        mock = @sandbox.mock(move).expects('hit').once()
        @battle.performMove(@p2, move)
        mock.verify()

      it "does not protect the user from attacks without the protect flag", ->
        shared.create.call(this)
        move = @battle.getMove("Feint")
        mock = @sandbox.mock(move).expects('hit').once()

        @battle.recordMove(@id2, move)
        @battle.determineTurnOrder()
        @battle.performMove(@p1, @battle.getMove(moveName))
        @battle.performMove(@p2, move)
        mock.verify()

  testProtectMove 'Protect'
  testProtectMove 'Detect'

  describe "Endure", ->
    testProtectCounterMove("Endure")

    it "always survives moves that would otherwise KO with 1 HP", ->
      shared.create.call(this)
      move = @battle.getMove("Tackle")
      hp = @p1.currentHP
      @sandbox.stub(move, 'baseDamage', -> hp)

      @battle.recordMove(@id2, @battle.getMove("Tackle"))
      @battle.determineTurnOrder()
      @battle.performMove(@p1, @battle.getMove("Endure"))
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p1.currentHP.should.equal 1

    it "disappears at the end of the turn", ->
      shared.create.call(this)

      @battle.recordMove(@id2, @battle.getMove("Tackle"))
      @battle.determineTurnOrder()
      @battle.performMove(@p1, @battle.getMove("Endure"))
      @battle.performMove(@p2, @battle.getMove("Tackle"))

      @p1.has(Attachment.Endure).should.be.true
      @battle.endTurn()
      @p1.has(Attachment.Endure).should.be.false

  describe "Feint", ->
    it "removes the Protect attachment, if any, on the target", ->
      shared.create.call(this)
      @p1.attach(Attachment.Protect)
      @p1.has(Attachment.Protect).should.be.true

      @battle.performMove(@p2, @battle.getMove("Feint"))
      @p1.has(Attachment.Protect).should.be.false

    it "removes the Wide Guard attachment, if any, on the target"
    it "removes the Quick Guard attachment, if any, on the target"

  describe "Payback", ->
    it "doubles base power if target has made a move this turn", ->
      shared.create.call(this)
      move = @battle.getMove("Payback")
      spy  = @sandbox.spy(move, 'basePower')

      @battle.performMove(@p2, @battle.getMove("Splash"))
      @battle.performMove(@p1, move)
      spy.returned(2 * move.power).should.be.true

    it "doesn't double base power otherwise", ->
      shared.create.call(this)
      move = @battle.getMove("Payback")
      spy  = @sandbox.spy(move, 'basePower')

      @battle.recordMove(@id2, @battle.getMove("Splash"))
      @battle.performMove(@p1, move)
      spy.returned(move.power).should.be.true

    it "doesn't double BP if target moved last turn, but not this turn", ->
      shared.create.call(this)
      move = @battle.getMove("Payback")
      spy  = @sandbox.spy(move, 'basePower')

      @battle.performMove(@p2, @battle.getMove("Splash"))

      @battle.endTurn()
      @battle.beginTurn()

      @battle.recordMove(@id2, @battle.getMove("Splash"))
      @battle.performMove(@p1, move)

      spy.returned(move.power).should.be.true

  describe "Curse", ->
    it "silently chooses a random enemy as the target", ->
      shared.create.call(this)

      move = @battle.getMove("Curse")
      targets = move.getTargets(@battle, @p1)

      should.exist targets
      targets.should.eql [ @p2 ]

    describe "for Ghost types", ->
      it "curses the opponent", ->
        shared.create.call(this)
        @p1.types = [ "Ghost" ]

        @battle.performMove(@p1, @battle.getMove("Curse"))
        @p2.has(Attachment.Curse).should.be.true

      it "damages the user for half of its HP, rounded down", ->
        shared.create.call(this)
        p = @p1
        p.types = [ "Ghost" ]
        maxHP = p.stat('hp')

        @battle.performMove(@p1, @battle.getMove("Curse"))
        p.currentHP.should.equal(maxHP - Math.floor(maxHP / 2))

      it "causes the opponent to lose 25% of their HP at end of turns", ->
        shared.create.call(this)
        @p1.types = [ "Ghost" ]
        p = @p2
        maxHP = p.stat('hp')
        quarterHP = Math.floor(maxHP / 4)

        @battle.performMove(@p1, @battle.getMove("Curse"))
        p.currentHP.should.equal(maxHP)

        @battle.endTurn()
        p.currentHP.should.equal(maxHP - quarterHP)

        @battle.endTurn()
        p.currentHP.should.equal(maxHP - 2 * quarterHP)

      it "causes the opponent to lose a minimum of 1 HP per turn", ->
        shared.create.call(this, team2: [Factory("Shedinja"), Factory("Magikarp")])
        @p1.types = [ "Ghost" ]
        @battle.performMove(@p1, @battle.getMove("Curse"))
        @battle.endTurn()
        @p2.currentHP.should.equal(0)

      it "can faint the user", ->
        shared.create.call(this)
        p = @p1
        p.types = [ "Ghost" ]
        p.currentHP = 1

        @battle.performMove(@p1, @battle.getMove("Curse"))
        p.isFainted().should.be.true

    describe "for non-Ghost types", ->
      it "raises Attack and Defense and lowers Speed", ->
        shared.create.call(this)
        p = @p1
        p.types = [ "Normal" ]

        @battle.performMove(@p1, @battle.getMove("Curse"))
        p.stages.should.containEql attack: 1, defense: 1, speed: -1

  testBasePowerBoostMove = (moveName, rawBasePower, maxBasePower, which) ->
    describe moveName, ->
      it "increases base power by 20 for each positive stat boost on #{which}", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)
        poke = { user: @p1, target: @p2 }
        {user, target} = poke

        move.basePower(@battle, user, target).should.equal rawBasePower

        poke[which].boost(attack: 1)
        move.basePower(@battle, user, target).should.equal rawBasePower + 20

        poke[which].boost(defense: 1)
        move.basePower(@battle, user, target).should.equal rawBasePower + 40

        poke[which].boost(speed: 2, specialAttack: -1)
        move.basePower(@battle, user, target).should.equal rawBasePower + 80

      it "has a maximum of #{maxBasePower} base power", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)
        poke = { user: @p1, target: @p2 }
        {user, target} = poke

        # Total base power would theoretically be rawBasePower + 840
        stats = {
          speed: 6, specialAttack: 6, attack: 6,
          defense: 6, specialDefense: 6, evasion: 6, accuracy: 6
        }
        poke[which].boost(stats)
        move.basePower(@battle, user, target).should.equal maxBasePower

  testBasePowerBoostMove("Stored Power", 20, 860, "user")
  testBasePowerBoostMove("Punishment",   60, 200, "target")

  describe "Destiny Bond", ->
    it "causes the attacker to faint the turn of use if the user faints", ->
      shared.create.call(this)

      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Destiny Bond"))
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p2.isFainted().should.be.true

    it "causes the attacker to faint any time before the user moves again", ->
      shared.create.call(this)

      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Destiny Bond"))

      @battle.endTurn()
      @battle.beginTurn()
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p2.isFainted().should.be.true

    it "does not cause attacker to faint after user moves again", ->
      shared.create.call(this)

      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Destiny Bond"))
      @battle.performMove(@p1, @battle.getMove("Splash"))
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p2.isFainted().should.be.false

    it "does not cause attacker to faint after user attempts to move again", ->
      shared.create.call(this)

      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("Destiny Bond"))

      @battle.endTurn()
      @battle.beginTurn()
      @p1.attach(Status.Sleep)
      @battle.performMove(@p1, @battle.getMove("Tackle"))
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p2.isFainted().should.be.false

    it "does not faint attacker if pokemon fainted naturally", ->
      shared.create.call(this)
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @battle.performMove(@p1, @battle.getMove("Destiny Bond"))
      @p1.faint()
      @battle.endTurn()
      @p2.isFainted().should.be.false

    it "does not faint attacker if opponent made move, but did not faint", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SAND)
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @battle.performMove(@p1, @battle.getMove("Destiny Bond"))
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p1.currentHP = 1
      @battle.endTurn()
      @p1.isFainted().should.be.true
      @p2.isFainted().should.be.false

    it "does not cause a party member to faint"
    it "handles 2+ pokemon destiny-bonding and all fainting at once"

  describe "Pursuit", ->
    it "doubles base power if the target switches", ->
      shared.create.call this,
        team2: [ Factory("Magikarp"), Factory("Magikarp") ]
      pursuit = @battle.getMove("Pursuit")
      spy = @sandbox.spy(pursuit, 'basePower')

      @battle.recordSwitch(@id2, 1)
      @battle.recordMove(@id1, pursuit)
      @battle.continueTurn()
      spy.alwaysReturned(2 * pursuit.power).should.be.true

    it "doubles BP if a faster target uses a damaging switch move", ->
      shared.create.call this,
        team2: [ Factory("Magikarp", evs: {speed: 4}), Factory("Magikarp") ]
      pursuit = @battle.getMove("Pursuit")
      spy = @sandbox.spy(pursuit, 'basePower')

      @battle.recordMove(@id2, @battle.getMove("U-turn"))
      @battle.recordMove(@id1, pursuit)
      @battle.continueTurn()
      @battle.recordSwitch(@id2, 1)  # battle.forceSwitch makes a request
      @battle.continueTurn()
      spy.alwaysReturned(2 * pursuit.power).should.be.true

    it "doesn't double BP if a slower target uses a damaging switch move", ->
      shared.create.call this,
        team1: [ Factory("Magikarp", evs: {speed: 4}) ]
        team2: [ Factory("Magikarp"), Factory("Magikarp") ]
      pursuit = @battle.getMove("Pursuit")
      spy = @sandbox.spy(pursuit, 'basePower')

      @battle.recordMove(@id1, pursuit)
      @battle.recordMove(@id2, @battle.getMove("U-turn"))
      @battle.continueTurn()
      @battle.recordSwitch(@id2, 1)  # battle.forceSwitch makes a request
      @battle.continueTurn()
      spy.alwaysReturned(pursuit.power).should.be.true

    it "has perfect accuracy if target is switching", ->
      shared.create.call this,
        team2: [ Factory("Magikarp"), Factory("Magikarp") ]
      pursuit = @battle.getMove("Pursuit")
      spy = @sandbox.spy(pursuit, 'chanceToHit')

      pursuit = @battle.getMove("Pursuit")
      @battle.recordSwitch(@id2, 1)
      @battle.recordMove(@id1, pursuit)
      @battle.continueTurn()
      spy.alwaysReturned(0).should.be.true

    it "runs only once", ->
      shared.create.call this,
        team2: [ Factory("Magikarp"), Factory("Magikarp") ]
      pursuit = @battle.getMove("Pursuit")
      mock = @sandbox.mock(pursuit).expects('execute').once()

      pursuit = @battle.getMove("Pursuit")
      @battle.recordSwitch(@id2, 1)
      @battle.recordMove(@id1, pursuit)
      @battle.continueTurn()
      @battle.recordSwitch(@id2, 1)  # battle.forceSwitch makes a request
      @battle.continueTurn()
      mock.verify()

    it "doesn't double BP on a faster Baton Passer", ->
      shared.create.call this,
        team1: [ Factory("Magikarp") ]
        team2: [ Factory("Magikarp", evs: {speed: 4}), Factory("Magikarp") ]
      pursuit = @battle.getMove("Pursuit")
      spy = @sandbox.spy(pursuit, 'basePower')

      @battle.recordMove(@id1, pursuit)
      @battle.recordMove(@id2, @battle.getMove("Baton Pass"))
      @battle.continueTurn()
      @battle.recordSwitch(@id2, 1)  # battle.forceSwitch makes a request
      @battle.continueTurn()
      spy.alwaysReturned(pursuit.power).should.be.true

    it "emits the move name when target switches", ->
      shared.create.call this,
        team1: [ Factory("Magikarp") ]
        team2: [ Factory("Magikarp", evs: {speed: 4}), Factory("Magikarp") ]
      pursuit = @battle.getMove("Pursuit")
      spy = @sandbox.spy(@battle, 'tell')

      @battle.recordMove(@id1, pursuit)
      @battle.recordSwitch(@id2, 1)
      @battle.continueTurn()
      spy.calledWith(Protocol.MAKE_MOVE).should.be.true

    it "records the move when target switches", ->
      shared.create.call this,
        team1: [ Factory("Magikarp") ]
        team2: [ Factory("Magikarp", evs: {speed: 4}), Factory("Magikarp") ]
      pursuit = @battle.getMove("Pursuit")
      mock = @sandbox.mock(@p1).expects('recordMove').once()

      @battle.recordMove(@id1, pursuit)
      @battle.recordSwitch(@id2, 1)
      @battle.continueTurn()
      mock.verify()

    it "does not trigger if asleep", ->
      shared.create.call(this)

      @p1.attach(Status.Sleep, turns: 4)
      pursuit = @battle.getMove("Pursuit")
      mock = @sandbox.mock(pursuit).expects('hit').never()

      @battle.recordMove(@id1, pursuit)
      @battle.recordSwitch(@id2, 1)
      @battle.continueTurn()
      mock.verify()

    it "does not trigger on team members"

  describe 'Power Swap', ->
    it 'swaps attack and special attack boosts with the target', ->
      shared.create.call(this)
      @p1.boost(attack: 1, specialAttack: -3, speed: 1)
      @p2.boost(attack: 2, specialAttack: 6, defense: -1)

      @battle.performMove(@p1, @battle.getMove('Power Swap'))

      @p1.stages.should.containEql attack: 2, specialAttack: 6, speed: 1
      @p2.stages.should.containEql attack: 1, specialAttack: -3, defense: -1

  describe 'Guard Swap', ->
    it 'swaps defense and special defense boosts with the target', ->
      shared.create.call(this)
      @p1.boost(attack: 1, specialDefense: -3, defense: 1)
      @p2.boost(speed: 2, specialDefense: 6, defense: -1)

      @battle.performMove(@p1, @battle.getMove('Guard Swap'))

      @p1.stages.should.containEql defense: -1, specialDefense: 6, attack: 1
      @p2.stages.should.containEql defense: 1, specialDefense: -3, speed: 2

  describe 'Spite', ->
    it 'reduces the last move used by the target by 4', ->
      shared.create.call(this)

      move = @p2.moves[0]
      pp = @p2.pp(move)
      @battle.performMove(@p2, move)
      @battle.performMove(@p1, @battle.getMove('Spite'))
      @p2.pp(move).should.equal(pp - 4 - 1)

    it 'fails if the target has not recorded their last move', ->
      shared.create.call(this)
      spite = @battle.getMove('Spite')
      mock = @sandbox.mock(spite).expects('fail').once()

      @battle.performMove(@p1, spite)
      mock.verify()

    it "fails if the target's move has 0 PP", ->
      shared.create.call(this)
      spite = @battle.getMove('Spite')
      move = @p2.moves[0]
      mock = @sandbox.mock(spite).expects('fail').once()
      @p2.setPP(move, 0)

      @battle.performMove(@p2, move)
      @battle.performMove(@p1, spite)
      mock.verify()

    it 'fails if the target no longer knows the move', ->
      shared.create.call(this)
      spite = @battle.getMove('Spite')
      move = @p2.moves[0]
      mock = @sandbox.mock(spite).expects('fail').once()

      @battle.performMove(@p2, move)
      @p2.moves.splice(@p2.moves.indexOf(move), 1)
      @battle.performMove(@p1, spite)
      mock.verify()

  describe 'Wring Out', ->
    it 'has 120 power at maximum HP', ->
      shared.create.call(this)
      move = @battle.getMove('Wring Out')
      move.basePower(@battle, @p1, @p2).should.equal 120

    it 'has 59 power at half-of-odd HP (rounded down)', ->
      shared.create.call(this)
      @p1.currentHP >>= 1
      move = @battle.getMove('Wring Out')
      move.basePower(@battle, @p1, @p2).should.equal 59

    it 'has 1 power minimum', ->
      shared.create.call(this)
      @p1.currentHP = 1
      move = @battle.getMove('Wring Out')
      move.basePower(@battle, @p1, @p2).should.equal 1

  describe 'Assurance', ->
    it 'doubles base power if the user was damaged this turn', ->
      shared.create.call(this)
      move = @battle.getMove('Assurance')

      @battle.performMove(@p2, @battle.getMove('Tackle'))
      power = move.basePower(@battle, @p1, @p2)
      power.should.equal(2 * move.power)

    it "doesn't double base power if the user was damaged a different turn", ->
      shared.create.call(this)
      move = @battle.getMove('Assurance')

      @battle.performMove(@p2, @battle.getMove('Tackle'))
      @battle.endTurn()
      @battle.beginTurn()
      power = move.basePower(@battle, @p1, @p2)
      power.should.equal(move.power)

    it "doesn't double base power if the user has never used a move", ->
      shared.create.call(this)
      move = @battle.getMove('Assurance')
      power = move.basePower(@battle, @p1, @p2)
      power.should.equal(move.power)

    it "doesn't double base power if hit by a non-damaging move", ->
      shared.create.call(this)
      move = @battle.getMove('Assurance')
      @battle.performMove(@p2, @battle.getMove('Will-O-Wisp'))
      power = move.basePower(@battle, @p1, @p2)
      power.should.equal(move.power)

  describe "Substitute", ->
    shared.shouldDoNoDamage("Substitute")
    shared.shouldFailIfUsedTwice("Substitute")

    it "removes 25% of the owner's health, rounded down", ->
      shared.create.call(this)
      sub = @battle.getMove('Substitute')
      hp  = @p1.stat('hp')
      @battle.performMove(@p1, sub)
      @p1.currentHP.should.equal(hp - (hp >> 2))

    it "fails if the pokemon has 25% HP or less", ->
      shared.create.call(this)
      sub  = @battle.getMove('Substitute')
      hp   = @p1.stat('hp')
      mock = @sandbox.mock(sub).expects('fail').once()
      @p1.currentHP = hp >> 2
      @battle.performMove(@p1, sub)
      mock.verify()

    it "fails if the pokemon does not have enough total HP", ->
      shared.create.call(this, team1: [Factory("Shedinja")])
      sub  = @battle.getMove('Substitute')
      hp   = @p1.stat('hp')
      mock = @sandbox.mock(sub).expects('fail').once()
      @battle.performMove(@p1, sub)
      mock.verify()

    it "takes damage for the user", ->
      shared.create.call(this)
      sub   = @battle.getMove('Substitute')
      subHP = (@p1.stat('hp') >> 2)
      @battle.performMove(@p1, sub)
      hp    = @p1.currentHP

      attachment = @p1.get(Attachment.Substitute)
      attachment.hp.should.equal subHP
      @battle.performMove(@p2, @battle.getMove('Tackle'))

      attachment.hp.should.be.lessThan subHP
      @p1.currentHP.should.equal hp

    it "breaks after taking too much damage", ->
      shared.create.call(this)
      tackle = @battle.getMove('Tackle')
      sub    = @battle.getMove('Substitute')

      @battle.performMove(@p1, sub)
      hp     = @p1.currentHP
      @p1.has(Attachment.Substitute).should.be.true

      @sandbox.stub(tackle, 'baseDamage', -> 9999)
      @battle.performMove(@p2, tackle)
      @p1.has(Attachment.Substitute).should.be.false
      @p1.currentHP.should.equal hp

    it "fails most non-damaging moves", ->
      shared.create.call(this)
      hypnosis = @battle.getMove('Hypnosis')
      sub      = @battle.getMove('Substitute')

      @battle.performMove(@p1, sub)
      @p1.has(Attachment.Substitute).should.be.true

      mock = @sandbox.mock(hypnosis).expects('fail').once()
      @battle.performMove(@p2, hypnosis)
      mock.verify()

    it "does not fail stat-up moves", ->
      shared.create.call(this)
      dragonDance = @battle.getMove('Dragon Dance')
      sub         = @battle.getMove('Substitute')

      @battle.performMove(@p1, sub)
      @p1.has(Attachment.Substitute).should.be.true

      mock = @sandbox.mock(dragonDance).expects('fail').never()
      @battle.performMove(@p1, dragonDance)
      mock.verify()

    it "does not fail non-damaging moves with an authentic flag", ->
      shared.create.call(this)
      foresight = @battle.getMove('Foresight')
      sub       = @battle.getMove('Substitute')

      @battle.performMove(@p1, sub)
      @p1.has(Attachment.Substitute).should.be.true

      mock = @sandbox.mock(foresight).expects('fail').never()
      @battle.performMove(@p2, foresight)
      mock.verify()

    it "still stores the actual damage", ->
      shared.create.call(this)
      gigaDrain = @battle.getMove('Giga Drain')
      sub       = @battle.getMove('Substitute')

      @battle.performMove(@p1, sub)
      @p1.has(Attachment.Substitute).should.be.true

      spy = @sandbox.spy(@p2, 'drain')
      @battle.performMove(@p2, gigaDrain)
      spy.calledWith(0).should.be.false
      @p1.lastHitBy.damage.should.be.greaterThan 0

    it "blocks secondary effects", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", "secondary effect", 0)  # always burn
      flamethrower = @battle.getMove('Flamethrower')
      sub          = @battle.getMove('Substitute')

      @battle.performMove(@p1, sub)
      @p1.has(Attachment.Substitute).should.be.true

      @sandbox.stub(flamethrower, 'baseDamage', -> 1)
      @battle.performMove(@p2, flamethrower)
      @p1.has(Status.Burn).should.be.false

    it "blocks secondary effects even if sub fades", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", "secondary effect", 0)  # always burn
      flamethrower = @battle.getMove('Flamethrower')
      sub          = @battle.getMove('Substitute')

      @battle.performMove(@p1, sub)
      @p1.has(Attachment.Substitute).should.be.true

      @sandbox.stub(flamethrower, 'baseDamage', -> 9999)
      @battle.performMove(@p2, flamethrower)
      @p1.has(Status.Burn).should.be.false

    it "does not block sandstorm damage", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SAND)
      @battle.performMove(@p1, @battle.getMove('Substitute'))

      hp = @p1.currentHP
      @battle.endTurn()
      @p1.currentHP.should.be.lessThan(hp)

    it "does not block leech seed damage", ->
      shared.create.call(this)
      @battle.performMove(@p2, @battle.getMove('Leech Seed'))
      @battle.performMove(@p1, @battle.getMove('Substitute'))

      hp = @p1.currentHP
      @battle.endTurn()
      @p1.currentHP.should.be.lessThan(hp)

    it "is baton-passable"

  describe "Sucker Punch", ->
    it "fails if the target is not moving after the user", ->
      shared.create.call(this)
      suckerPunch = @battle.getMove('Sucker Punch')

      mock = @sandbox.mock(suckerPunch).expects('fail').once()
      @battle.performMove(@p1, suckerPunch)
      mock.verify()

    it "executes normally if the target is moving after the user", ->
      shared.create.call(this)
      suckerPunch = @battle.getMove('Sucker Punch')
      tackle = @battle.getMove('Tackle')

      mock = @sandbox.mock(suckerPunch).expects('afterSuccessfulHit').once()
      @battle.recordMove(@id2, tackle)
      @battle.determineTurnOrder()
      @battle.performMove(@p1, suckerPunch)
      mock.verify()

    it "fails if the target is using a status move", ->
      shared.create.call(this)
      suckerPunch = @battle.getMove('Sucker Punch')
      willOWisp = @battle.getMove('Will-O-Wisp')

      mock = @sandbox.mock(suckerPunch).expects('fail').once()
      @battle.recordMove(@id2, willOWisp)
      @battle.determineTurnOrder()
      @battle.performMove(@p1, suckerPunch)
      mock.verify()

  describe 'Grudge', ->
    it "causes the last move to lose all its PP if the user faints", ->
      shared.create.call(this)
      grudge = @battle.getMove("Grudge")
      tackle = @battle.getMove('Tackle')
      @p2.moves = [ tackle ]

      @p1.currentHP = 1
      @battle.performMove(@p1, grudge)
      @battle.performMove(@p2, tackle)
      @battle.performFaints()
      @p1.isFainted().should.be.true
      @p2.pp(tackle).should.equal 0

    it "causes the attacker to lose PP any time before the user moves again", ->
      shared.create.call(this)
      grudge = @battle.getMove("Grudge")
      tackle = @battle.getMove('Tackle')
      @p2.moves = [ tackle ]

      @p1.currentHP = 1
      @battle.performMove(@p1, grudge)
      @battle.endTurn()
      @battle.beginTurn()

      @battle.performMove(@p2, tackle)
      @battle.performFaints()
      @p2.pp(tackle).should.equal 0

    it "does not cause attacker to lose PP after user moves again", ->
      shared.create.call(this)
      grudge = @battle.getMove("Grudge")
      splash = @battle.getMove('Splash')
      tackle = @battle.getMove('Tackle')
      @p2.moves = [ tackle ]

      @p1.currentHP = 1
      @battle.performMove(@p1, grudge)
      @battle.performMove(@p1, splash)
      @battle.performMove(@p2, tackle)
      @battle.performFaints()
      @p2.pp(tackle).should.not.equal 0

    it "does not trigger from natural causes", ->
      shared.create.call(this)
      grudge = @battle.getMove("Grudge")
      splash = @battle.getMove('Splash')
      leechSeed = @battle.getMove('Leech Seed')
      @p2.moves = [ leechSeed ]
      @p2.resetAllPP()

      @p1.currentHP = 1
      @battle.performMove(@p1, grudge)
      @battle.performMove(@p2, leechSeed)
      @battle.endTurn()
      @p2.pp(leechSeed).should.equal(@p2.maxPP(leechSeed) - 1)

  describe "Stockpile", ->
    it "raises def and spdef", ->
      shared.create.call(this)
      stockpile = @battle.getMove("Stockpile")

      @p1.stages.should.containEql defense: 0, specialDefense: 0
      @battle.performMove(@p1, stockpile)
      @p1.stages.should.containEql defense: 1, specialDefense: 1

    it "cannot raise if stockpile is at its limit", ->
      shared.create.call(this)
      stockpile = @battle.getMove("Stockpile")

      for i in [0...Attachment.Stockpile::maxLayers]
        @p1.attach(Attachment.Stockpile)

      @p1.stages.should.containEql defense: 0, specialDefense: 0
      @battle.performMove(@p1, stockpile)
      @p1.stages.should.containEql defense: 0, specialDefense: 0

    it "fails if stockpile is at its limit", ->
      shared.create.call(this)
      stockpile = @battle.getMove("Stockpile")
      mock = @sandbox.mock(stockpile).expects('fail').once()

      for i in [0...Attachment.Stockpile::maxLayers]
        @p1.attach(Attachment.Stockpile)

      @battle.performMove(@p1, stockpile)
      mock.verify()

  describe 'Spit Up', ->
    it 'fails if user has no stockpiles', ->
      shared.create.call(this)
      spitUp = @battle.getMove("Spit Up")
      mock = @sandbox.mock(spitUp).expects('fail').once()

      @battle.performMove(@p1, spitUp)
      mock.verify()

    it "has 100 base power with 1 layer of stockpiles", ->
      shared.create.call(this)
      spitUp = @battle.getMove("Spit Up")
      @p1.attach(Attachment.Stockpile)

      spitUp.basePower(@battle, @p1, @p2).should.equal 100

    it "has 200 base power with 2 layers of stockpiles", ->
      shared.create.call(this)
      spitUp = @battle.getMove("Spit Up")
      @p1.attach(Attachment.Stockpile)
      @p1.attach(Attachment.Stockpile)

      spitUp.basePower(@battle, @p1, @p2).should.equal 200

    it "has 300 base power with 3 layers of stockpiles", ->
      shared.create.call(this)
      spitUp = @battle.getMove("Spit Up")
      @p1.attach(Attachment.Stockpile)
      @p1.attach(Attachment.Stockpile)
      @p1.attach(Attachment.Stockpile)

      spitUp.basePower(@battle, @p1, @p2).should.equal 300

    it "resets stockpile count to 0", ->
      shared.create.call(this)
      spitUp = @battle.getMove("Spit Up")
      @p1.attach(Attachment.Stockpile)

      @p1.get(Attachment.Stockpile).layers.should.equal 1
      @battle.performMove(@p1, spitUp)
      @p1.has(Attachment.Stockpile).should.be.false

    it "loses def/sp. def according to number of stockpiles", ->
      shared.create.call(this)
      spitUp = @battle.getMove("Spit Up")
      @p1.attach(Attachment.Stockpile)
      @p1.attach(Attachment.Stockpile)

      @p1.stages.should.containEql defense: 0, specialDefense: 0
      @battle.performMove(@p1, spitUp)
      @p1.stages.should.containEql defense: -2, specialDefense: -2

  describe 'Swallow', ->
    it 'fails if user has no stockpiles', ->
      shared.create.call(this)
      swallow = @battle.getMove("Swallow")
      mock = @sandbox.mock(swallow).expects('fail').once()

      @battle.performMove(@p1, swallow)
      mock.verify()

    it "heals 25% of its HP, rounded half-down, with 1 layer of stockpiles", ->
      shared.create.call(this)
      swallow = @battle.getMove("Swallow")
      @p1.attach(Attachment.Stockpile)

      @p1.currentHP = 1
      @battle.performMove(@p1, swallow)
      @p1.currentHP.should.equal(1 + util.roundHalfDown(@p1.stat('hp') / 4))

    it "heals 50% of its HP, rounded half-down, with 2 layers of stockpiles", ->
      shared.create.call(this)
      swallow = @battle.getMove("Swallow")
      @p1.attach(Attachment.Stockpile)
      @p1.attach(Attachment.Stockpile)

      @p1.currentHP = 1
      @battle.performMove(@p1, swallow)
      @p1.currentHP.should.equal(1 + util.roundHalfDown(@p1.stat('hp') / 2))

    it "heals all of its HP with 3 layers of stockpiles", ->
      shared.create.call(this)
      swallow = @battle.getMove("Swallow")
      @p1.attach(Attachment.Stockpile)
      @p1.attach(Attachment.Stockpile)
      @p1.attach(Attachment.Stockpile)

      @p1.currentHP = 1
      @battle.performMove(@p1, swallow)
      @p1.currentHP.should.equal @p1.stat('hp')

    it "resets stockpile count to 0", ->
      shared.create.call(this)
      swallow = @battle.getMove("Swallow")
      @p1.attach(Attachment.Stockpile)

      @p1.get(Attachment.Stockpile).layers.should.equal 1
      @battle.performMove(@p1, swallow)
      @p1.has(Attachment.Stockpile).should.be.false

    it "loses def/sp. def according to number of stockpiles", ->
      shared.create.call(this)
      swallow = @battle.getMove("Swallow")
      @p1.attach(Attachment.Stockpile)
      @p1.attach(Attachment.Stockpile)

      @p1.stages.should.containEql defense: 0, specialDefense: 0
      @battle.performMove(@p1, swallow)
      @p1.stages.should.containEql defense: -2, specialDefense: -2

  describe 'Rage', ->
    it "raises the user's attack if hit by a move", ->
      shared.create.call(this)
      rage = @battle.getMove('Rage')
      tackle = @battle.getMove('Tackle')

      @p1.stages.attack.should.equal 0
      @battle.performMove(@p1, rage)
      @battle.performMove(@p2, tackle)
      @p1.stages.attack.should.equal 1

    it "doesn't raise the user's attack if user chooses another move", ->
      shared.create.call(this)
      rage = @battle.getMove('Rage')
      tackle = @battle.getMove('Tackle')

      @p1.stages.attack.should.equal 0
      @battle.performMove(@p1, rage)
      @battle.performMove(@p1, tackle)
      @battle.performMove(@p2, tackle)
      @p1.stages.attack.should.equal 0

    it "doesn't raise the user's attack if hit by a non-damaging move", ->
      shared.create.call(this)
      rage = @battle.getMove('Rage')
      willOWisp = @battle.getMove('Will-O-Wisp')

      @p1.stages.attack.should.equal 0
      @battle.performMove(@p1, rage)
      @battle.performMove(@p2, willOWisp)
      @p1.stages.attack.should.equal 0

  testRevengeMove = (moveName) ->
    describe moveName, ->
      it "doubles base power if hit by an attack that turn", ->
        shared.create.call(this)
        revenge = @battle.getMove(moveName)
        tackle  = @battle.getMove("Tackle")

        @battle.performMove(@p2, tackle)
        revenge.basePower(@battle, @p1, @p2).should.equal(2 * revenge.power)

      it "doesn't double base power if not hit by an attack that turn", ->
        shared.create.call(this)
        revenge = @battle.getMove(moveName)
        revenge.basePower(@battle, @p1, @p2).should.equal(revenge.power)

      it "doesn't double base power if hit by a non-damaging move", ->
        shared.create.call(this)
        revenge = @battle.getMove(moveName)
        willOWisp  = @battle.getMove("Will-O-Wisp")

        @battle.performMove(@p2, willOWisp)
        revenge.basePower(@battle, @p1, @p2).should.equal(revenge.power)

      it "doesn't double base power if hit last turn, but not this turn", ->
        shared.create.call(this)
        revenge = @battle.getMove(moveName)
        tackle  = @battle.getMove("Tackle")

        @battle.performMove(@p2, tackle)
        @battle.beginTurn()
        revenge.basePower(@battle, @p1, @p2).should.equal(revenge.power)

  testRevengeMove("Avalanche")
  testRevengeMove("Revenge")

  testIgnoreStagesMove = (moveName) ->
    describe moveName, ->
      it "ignores the target's defensive and evasive stat stages", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)
        stats = [ 'defense', 'specialDefense', 'evasion' ]
        values = ( @p2.stat(stat)  for stat in stats )
        spy = @sandbox.spy(@p2, 'stat')
        spy.withArgs(stat)  for stat in stats

        @p2.boost(defense: -3, specialDefense: 2, evasion: 6)
        @battle.performMove(@p1, move)

        for i in [0...stats.length]
          stat  = stats[i]
          value = values[i]
          continue  if spy.withArgs(stat).returnValues.length == 0
          spy.withArgs(stat).alwaysReturned(value).should.be.true

  testIgnoreStagesMove("Chip Away")
  testIgnoreStagesMove("Sacred Sword")

  describe 'Captivate', ->
    it 'fails if the user and target are not opposite genders', ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "M")]
        team2: [Factory("Magikarp", gender: "M")]
      captivate = @battle.getMove('Captivate')
      mock = @sandbox.mock(captivate).expects('fail').once()

      @battle.performMove(@p1, captivate)
      mock.verify()

    it "lowers the target's special attack by 2", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "M")]
        team2: [Factory("Magikarp", gender: "F")]
      captivate = @battle.getMove('Captivate')

      @p2.stages.specialAttack.should.equal 0
      @battle.performMove(@p1, captivate)
      @p2.stages.specialAttack.should.equal -2

  testStatusCureAttackMove = (moveName, status) ->
    describe moveName, ->
      it "doubles base power if the target has #{status.name}", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)

        @p2.attach(status)
        move.basePower(@battle, @p1, @p2).should.equal(2 * move.power)

      it "doesn't double if the target doesn't have #{status.name}", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)

        move.basePower(@battle, @p1, @p2).should.equal(move.power)

      it "cures the target of #{status.name}", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)

        @p2.attach(status)
        @p2.has(status).should.be.true
        @battle.performMove(@p1, move)
        @p2.hasStatus().should.be.false

      it "does not cure #{status.name} if the user faints", ->
        shared.create.call(this, team2: [Factory("Magikarp", ability: "Iron Barbs")])

        move = @battle.getMove(moveName)

        @p1.currentHP = 1
        @p2.attach(status)
        @p2.has(status).should.be.true
        @battle.performMove(@p1, move)
        @p2.hasStatus().should.be.true

  testStatusCureAttackMove("Wake-Up Slap", Status.Sleep)
  testStatusCureAttackMove("SmellingSalt", Status.Paralyze)

  describe 'Aqua Ring', ->
    it "restores 1/16 max HP at the end of each turn", ->
      shared.create.call(this)
      aquaRing = @battle.getMove('Aqua Ring')
      delta = @p1.currentHP >> 4

      @p1.currentHP = 1
      @battle.performMove(@p1, aquaRing)
      @p1.currentHP.should.equal(1)
      @battle.endTurn()
      @p1.currentHP.should.equal(1 + delta)

  describe 'Ingrain', ->
    it "restores 1/16 max HP at the end of each turn", ->
      shared.create.call(this)
      ingrain = @battle.getMove('Ingrain')
      delta = @p1.currentHP >> 4

      @p1.currentHP = 1
      @battle.performMove(@p1, ingrain)
      @p1.currentHP.should.equal(1)
      @battle.endTurn()
      @p1.currentHP.should.equal(1 + delta)

    it "prevents switching", ->
      shared.create.call(this)
      ingrain = @battle.getMove('Ingrain')

      @battle.performMove(@p1, ingrain)
      @battle.beginTurn()
      @p1.isSwitchBlocked().should.be.true

    it "prevents self from being phased", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      ingrain = @battle.getMove('Ingrain')
      whirlwind = @battle.getMove('Whirlwind')

      @battle.performMove(@p1, ingrain)

      mock = @sandbox.mock(@team1).expects('switch').never()
      @battle.performMove(@p2, whirlwind)
      mock.verify()

    it "lets self be switched out if using self-switching moves", ->
      shared.create.call(this)
      ingrain = @battle.getMove('Ingrain')
      uTurn = @battle.getMove('U-turn')

      @battle.performMove(@p1, ingrain)

      mock = @sandbox.mock(@battle).expects('requestActions').once()
      @battle.performMove(@p1, uTurn)
      mock.verify()

    it "makes self vulnerable to Ground moves", ->
      shared.create.call(this, team1: [ Factory("Gyarados") ])
      ingrain = @battle.getMove('Ingrain')
      uTurn = @battle.getMove('U-turn')

      @p1.isImmune('Ground').should.be.true
      @battle.performMove(@p1, ingrain)
      @p1.isImmune('Ground').should.be.false

    it "causes Telekinesis to fail", ->
      shared.create.call(this)
      ingrain = @battle.getMove('Ingrain')
      telekinesis = @battle.getMove('Telekinesis')

      @battle.performMove(@p1, ingrain)

      mock = @sandbox.mock(telekinesis).expects('fail').once()
      @battle.performMove(@p2, telekinesis)
      mock.verify()

  describe "Embargo", ->
    it "prevents the target's use of items", ->
      shared.create.call this,
        team2: [ Factory("Magikarp", item: "Leftovers") ]
      embargo = @battle.getMove('Embargo')
      mock = @sandbox.mock(@p2.get(@p2.item)).expects('endTurn').never()

      @battle.performMove(@p1, embargo)
      @battle.endTurn()
      mock.verify()

    it "lasts 5 turns", ->
      shared.create.call this,
        team2: [ Factory("Magikarp", item: "Leftovers") ]
      embargo = @battle.getMove('Embargo')
      mock = @sandbox.mock(@p2.get(@p2.item)).expects('endTurn').never()
      @battle.performMove(@p1, embargo)

      for i in [0...5]
        @p2.has(Attachment.Embargo).should.be.true
        @battle.endTurn()
      @p2.has(Attachment.Embargo).should.be.false

    it "prevents the target's use of items in subsequent turns", ->
      shared.create.call this,
        team2: [ Factory("Magikarp", item: "Leftovers") ]
      embargo = @battle.getMove('Embargo')
      mock = @sandbox.mock(@p2.get(@p2.item)).expects('endTurn').never()
      @battle.performMove(@p1, embargo)

      for i in [0...5]
        @battle.endTurn()
        @battle.beginTurn()
      mock.verify()

  testChargeMove = (moveName, vulnerable) ->
    describe moveName, ->
      it "chooses the player's next action for them", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)
        @p1.moves = [ move ]

        @battle.recordMove(@id1, move)
        @battle.continueTurn()
        @battle.endTurn()
        @battle.beginTurn()
        @battle.requests.should.not.have.property(@id1)
        should.exist(@battle.getAction(@p1))

      it "only spends 1 PP for the entire attack", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)
        @p1.moves = [ move ]
        @p1.resetAllPP()

        pp = @p1.pp(move)
        @battle.recordMove(@id1, move)
        @battle.continueTurn()
        @p1.pp(move).should.equal(pp)
        @battle.beginTurn()
        @battle.continueTurn()
        @p1.pp(move).should.equal(pp - 1)

      it "skips the charge turn if the user is holding a Power Herb", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: "Power Herb")]
        move = @battle.getMove(moveName)

        @p1.hasItem("Power Herb").should.be.true
        mock = @sandbox.mock(move).expects('execute').once()
        @battle.recordMove(@id1, move)
        @battle.continueTurn()
        mock.verify()
        @p1.hasItem().should.be.false

      if vulnerable?.length?
        it "makes target invulnerable to moves", ->
          shared.create.call this,
            team1: [Factory("Magikarp", evs: {speed: 4})]
          move = @battle.getMove(moveName)
          tackle = @battle.getMove("Tackle")

          @battle.recordMove(@id1, move)
          @battle.recordMove(@id2, tackle)

          mock = @sandbox.mock(tackle).expects('hit').never()
          @battle.continueTurn()
          mock.verify()

        it "makes target invulnerable to moves *after* use", ->
          shared.create.call this,
            team2: [Factory("Magikarp", evs: {speed: 4})]
          move = @battle.getMove(moveName)
          tackle = @battle.getMove("Tackle")

          @battle.recordMove(@id1, move)
          @battle.recordMove(@id2, tackle)

          mock = @sandbox.mock(tackle).expects('hit').once()
          @battle.continueTurn()
          mock.verify()

        it "is vulnerable to attacks from a No Guard pokemon", ->
          shared.create.call this,
            team2: [Factory("Magikarp", ability: "No Guard")]
          move = @battle.getMove(moveName)
          tackle = @battle.getMove("Tackle")

          @battle.recordMove(@id1, move)
          @battle.recordMove(@id2, tackle)

          mock = @sandbox.mock(tackle).expects('hit').once()
          @battle.continueTurn()
          mock.verify()

        it "is vulnerable to attacks if locked on"

        for vulnerableMove in vulnerable
          it "is vulnerable to #{vulnerableMove}", ->
            shared.create.call this,
              team1: [Factory("Magikarp", evs: {speed: 4})]
            move = @battle.getMove(moveName)
            vulnerable = @battle.getMove(vulnerableMove)

            @battle.recordMove(@id1, move)
            @battle.recordMove(@id2, vulnerable)

            mock = @sandbox.mock(vulnerable).expects('hit').once()
            @battle.continueTurn()
            mock.verify()
      else # no vulnerable moves
        it "doesn't make target invulnerable to moves", ->
          shared.create.call this,
            team1: [Factory("Magikarp", evs: {speed: 4})]
          move = @battle.getMove(moveName)
          tackle = @battle.getMove("Tackle")

          @battle.recordMove(@id1, move)
          @battle.recordMove(@id2, tackle)

          mock = @sandbox.mock(tackle).expects('hit').once()
          @battle.continueTurn()
          mock.verify()

  testChargeMove('Skull Bash')
  testChargeMove('Razor Wind')
  testChargeMove('Shadow Force', [])
  testChargeMove('Ice Burn')
  testChargeMove('Freeze Shock')
  testChargeMove('Fly', ["Gust", "Thunder", "Twister", "Sky Uppercut", "Hurricane", "Smack Down"])
  testChargeMove('Bounce', ["Gust", "Thunder", "Twister", "Sky Uppercut", "Hurricane", "Smack Down"])  # Additional 30% chance to par
  testChargeMove('Dig', ["Earthquake", "Magnitude"])
  testChargeMove('Dive', ["Surf", "Whirlpool"])
  testChargeMove('SolarBeam')
  testChargeMove('Sky Attack')

  describe "Skull Bash", ->
    it "raises defense of the user on the charge turn", ->
      shared.create.call(this)
      skullBash = @battle.getMove('Skull Bash')
      @p1.stages.defense.should.equal(0)
      @battle.performMove(@p1, skullBash)
      @p1.stages.defense.should.equal(1)

  describe "Sky Attack", ->
    it "has a 30% chance to flinch after execution", ->
      shared.create.call(this)
      skyAttack = @battle.getMove('Sky Attack')
      shared.biasRNG.call(this, "randInt", 'flinch', 0)  # 100% chance

      @battle.recordMove(@id1, skyAttack)
      @battle.continueTurn()
      @p2.has(Attachment.Flinch).should.be.false
      @battle.beginTurn()
      @battle.continueTurn()
      @p2.has(Attachment.Flinch).should.be.true

  for moveName in [ "Gust", "Twister" ]
    for chargeMoveName in [ "Fly", "Bounce" ]
      do (moveName, chargeMoveName) ->
        describe moveName, ->
          it "deals double damage to Pokemon using #{chargeMoveName}", ->
            shared.create.call(this)
            chargeMove = @battle.getMove(chargeMoveName)
            move = @battle.getMove(moveName)

            # Make the Pokemon charge
            @battle.recordMove(@id2, chargeMove)
            @battle.continueTurn()

            move.basePower(@battle, @p1, @p2).should.equal(2 * move.power)

  for moveName in [ "Surf", "Whirlpool" ]
    do (moveName) ->
      describe moveName, ->
        it "deals double damage to Pokemon using Dive", ->
          shared.create.call(this)
          dive = @battle.getMove("Dive")
          move = @battle.getMove(moveName)

          # Make the Pokemon charge
          @battle.recordMove(@id2, dive)
          @battle.continueTurn()

          move.basePower(@battle, @p1, @p2).should.equal(2 * move.power)

  for moveName in [ "Earthquake", "Magnitude" ]
    do (moveName) ->
      describe moveName, ->
        it "deals double damage to Pokemon using Dig", ->
          shared.create.call(this)
          dig = @battle.getMove("Dig")
          move = @battle.getMove(moveName)
          power = move.power
          if moveName == 'Magnitude'
            power = 50
            shared.biasRNG.call(this, 'randInt', 'magnitude', 20)

          # Make the Pokemon charge
          @battle.recordMove(@id2, dig)
          @battle.continueTurn()

          move.basePower(@battle, @p1, @p2).should.equal(2 * power)

  describe "SolarBeam", ->
    it "skips the charge turn under Sun", ->
      shared.create.call(this)
      solarBeam = @battle.getMove("SolarBeam")
      @battle.setWeather(Weather.SUN)

      mock = @sandbox.mock(solarBeam).expects('execute').once()
      @battle.recordMove(@id1, solarBeam)
      @battle.continueTurn()
      mock.verify()

    for weather in [ Weather.RAIN, Weather.SAND, Weather.HAIL ]
      do (weather) ->
        it "halves base power under #{weather}", ->
          shared.create.call(this)
          move = @battle.getMove("SolarBeam")
          @battle.setWeather(weather)

          move.basePower(@battle, @p1, @p2).should.equal(move.power >> 1)

  describe "Fury Cutter", ->
    it "doubles base power after every use, to a max of 160", ->
      shared.create.call(this)
      furyCutter = @battle.getMove("Fury Cutter")
      furyCutter.basePower(@battle, @p1, @p2).should.equal(20)
      @battle.performMove(@p1, furyCutter)
      furyCutter.basePower(@battle, @p1, @p2).should.equal(40)
      @battle.performMove(@p1, furyCutter)
      furyCutter.basePower(@battle, @p1, @p2).should.equal(80)
      @battle.performMove(@p1, furyCutter)
      furyCutter.basePower(@battle, @p1, @p2).should.equal(160)
      @battle.performMove(@p1, furyCutter)
      furyCutter.basePower(@battle, @p1, @p2).should.equal(160)

    it "resets to normal base power if using a different move", ->
      shared.create.call(this)
      furyCutter = @battle.getMove("Fury Cutter")
      splash = @battle.getMove("Splash")

      @battle.performMove(@p1, furyCutter)
      furyCutter.basePower(@battle, @p1, @p2).should.equal(40)
      @battle.performMove(@p1, splash)
      furyCutter.basePower(@battle, @p1, @p2).should.equal(20)

  describe "Imprison", ->
    shared.shouldDoNoDamage("Imprison")
    shared.shouldFailIfUsedTwice("Imprison")

    it "prevents the opponent from selecting moves that the user knows", ->
      shared.create.call(this)
      imprison = @battle.getMove("Imprison")
      furyCutter = @battle.getMove("Fury Cutter")
      tackle = @battle.getMove("Tackle")
      splash = @battle.getMove("Splash")
      @p1.moves = [ imprison, tackle, splash ]
      @p2.moves = [ furyCutter, tackle, splash ]
      @p1.resetAllPP()
      @p2.resetAllPP()

      @p2.validMoves().should.eql [ furyCutter, tackle, splash ]
      @battle.performMove(@p1, imprison)
      @battle.beginTurn()
      @p2.validMoves().should.eql [ furyCutter ]

    it "prevents the opponent from executing moves that the user knows", ->
      shared.create.call(this)
      imprison = @battle.getMove("Imprison")
      furyCutter = @battle.getMove("Fury Cutter")
      tackle = @battle.getMove("Tackle")
      splash = @battle.getMove("Splash")
      @p1.moves = [ imprison, tackle, splash ]
      @p2.moves = [ furyCutter, tackle, splash ]
      @p1.resetAllPP()
      @p2.resetAllPP()

      @battle.performMove(@p1, imprison)
      mock = @sandbox.mock(tackle).expects('execute').never()
      @battle.performMove(@p2, tackle)
      mock.verify()

    it "lets opponents use moves again after user switches out", ->
      shared.create.call this,
        team1: [Factory("Magikarp"), Factory("Magikarp")]
      imprison = @battle.getMove("Imprison")
      furyCutter = @battle.getMove("Fury Cutter")
      tackle = @battle.getMove("Tackle")
      splash = @battle.getMove("Splash")
      @p1.moves = [ imprison, tackle, splash ]
      @p2.moves = [ furyCutter, tackle, splash ]
      @p1.resetAllPP()
      @p2.resetAllPP()

      @battle.performMove(@p1, imprison)
      @battle.beginTurn()
      @p2.validMoves().should.eql [ furyCutter ]

      @battle.performSwitch(@team1.first(), 1)
      @battle.beginTurn()
      @p2.validMoves().should.eql [ furyCutter, tackle, splash ]

  describe "Present", ->
    it "has a 40% chance for 40 base power", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", "present", .6)
      present = @battle.getMove("Present")

      spy = @sandbox.spy(present, 'basePower')
      @battle.performMove(@p1, present)
      spy.alwaysReturned(40).should.be.true

    it "has a 30% chance for 80 base power", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", "present", .3)
      present = @battle.getMove("Present")

      spy = @sandbox.spy(present, 'basePower')
      @battle.performMove(@p1, present)
      spy.alwaysReturned(80).should.be.true

    it "has a 10% chance for 120 base power", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", "present", 0)
      present = @battle.getMove("Present")

      spy = @sandbox.spy(present, 'basePower')
      @battle.performMove(@p1, present)
      spy.alwaysReturned(120).should.be.true

    it "has a 20% chance to heal target by 25% HP, rounded down", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "next", "present", .1)
      present = @battle.getMove("Present")

      @p2.currentHP = 1
      spy = @sandbox.spy(present, 'basePower')
      @battle.performMove(@p1, present)
      spy.alwaysReturned(0).should.be.true
      @p2.currentHP.should.equal(1 + (@p2.stat('hp') >> 2))

  describe "Final Gambit", ->
    it "faints the user", ->
      shared.create.call(this)
      finalGambit = @battle.getMove("Final Gambit")
      @battle.performMove(@p1, finalGambit)
      @p1.isFainted().should.be.true

    it "deals damage equal to the user's HP to the target", ->
      shared.create.call(this, team2: [Factory("Magikarp", evs: {hp: 4})])
      finalGambit = @battle.getMove("Final Gambit")
      @battle.performMove(@p1, finalGambit)
      @p2.currentHP.should.equal(1)

  describe "Lucky Chant", ->
    shared.shouldDoNoDamage("Lucky Chant")
    shared.shouldFailIfUsedTwice("Lucky Chant")

    it "prevents critical hits on the defender's team", ->
      shared.create.call(this)
      luckyChant = @battle.getMove("Lucky Chant")
      stormThrow = @battle.getMove("Storm Throw")
      @battle.performMove(@p1, luckyChant)

      stormThrow.isCriticalHit(@battle, @p2, @p1).should.be.false

    it "lasts 5 turns", ->
      shared.create.call(this)
      luckyChant = @battle.getMove("Lucky Chant")
      @battle.performMove(@p1, luckyChant)

      for i in [0...5]
        @team1.has(Attachment.LuckyChant).should.be.true
        @battle.endTurn()
      @team1.has(Attachment.LuckyChant).should.be.false

  describe "Lunar Dance", ->
    it "faints the user", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      lunarDance = @battle.getMove("Lunar Dance")
      @battle.performMove(@p1, lunarDance)

      @p1.isFainted().should.be.true

    it "fails if the user is the last active pokemon", ->
      shared.create.call(this, team1: [Factory('Magikarp')])
      lunarDance = @battle.getMove("Lunar Dance")

      mock = @sandbox.mock(lunarDance).expects('fail').once()
      @battle.performMove(@p1, lunarDance)
      mock.verify()
      @p1.isFainted().should.be.false

    it "completely restores the switchin's HP, PP, and status", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      lunarDance = @battle.getMove("Lunar Dance")
      benched = @team1.at(1)
      benched.attach(Status.Burn)
      benched.currentHP = 1
      benched.setPP(benched.moves[0], 1)

      @battle.performMove(@p1, lunarDance)
      @battle.performSwitch(@team1.first(), 1)
      benched.currentHP.should.equal(benched.stat('hp'))
      benched.hasStatus().should.be.false
      for move in benched.moves
        benched.pp(move).should.equal(benched.maxPP(move))

    it "disappears afterward", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      lunarDance = @battle.getMove("Lunar Dance")

      @battle.performMove(@p1, lunarDance)
      @team1.has(Attachment.LunarDance).should.be.true
      @battle.performSwitch(@team1.first(), 1)
      @team1.has(Attachment.LunarDance).should.be.false

    it "works for 2v2"

  describe "Healing Wish", ->
    it "faints the user", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      healingWish = @battle.getMove("Healing Wish")
      @battle.performMove(@p1, healingWish)

      @p1.isFainted().should.be.true

    it "fails if the user is the last active pokemon", ->
      shared.create.call(this, team1: [Factory('Magikarp')])
      healingWish = @battle.getMove("Healing Wish")

      mock = @sandbox.mock(healingWish).expects('fail').once()
      @battle.performMove(@p1, healingWish)
      mock.verify()
      @p1.isFainted().should.be.false

    it "completely restores the switchin's HP and status", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      healingWish = @battle.getMove("Healing Wish")
      benched = @team1.at(1)
      benched.attach(Status.Burn)
      benched.currentHP = 1
      benched.setPP(benched.moves[0], 1)

      @battle.performMove(@p1, healingWish)
      @battle.performSwitch(@team1.first(), 1)
      benched.currentHP.should.equal(benched.stat('hp'))
      benched.hasStatus().should.be.false

    it "disappears afterward", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      healingWish = @battle.getMove("Healing Wish")

      @battle.performMove(@p1, healingWish)
      @team1.has(Attachment.HealingWish).should.be.true
      @battle.performSwitch(@team1.first(), 1)
      @team1.has(Attachment.HealingWish).should.be.false

    it "works for 2v2"

  describe "Last Resort", ->
    it "fails if the pokemon only has one move", ->
      shared.create.call(this)
      lastResort = @battle.getMove("Last Resort")
      @p1.moves = [ lastResort ]

      mock = @sandbox.mock(lastResort).expects('fail').once()
      @battle.performMove(@p1, lastResort)
      mock.verify()

    it "works if the pokemon uses all other moves before Last Resort", ->
      shared.create.call(this)
      lastResort = @battle.getMove("Last Resort")
      splash = @battle.getMove("Splash")
      @p1.moves = [ lastResort, splash ]

      @battle.performMove(@p1, splash)
      mock = @sandbox.mock(lastResort).expects('afterSuccessfulHit').once()
      @battle.performMove(@p1, lastResort)
      mock.verify()

    it "fails if using all moves, but switches out and back in", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      lastResort = @battle.getMove("Last Resort")
      splash = @battle.getMove("Splash")
      @p1.moves = [ lastResort, splash ]

      mock = @sandbox.mock(lastResort).expects('fail').once()
      @battle.performMove(@p1, splash)
      @battle.performSwitch(@team1.first(), 1)
      @battle.performMove(@team1.first(), lastResort)
      @battle.performSwitch(@team1.first(), 1)
      mock.verify()

    it "fails if the pokemon does not know Last Resort", ->
      shared.create.call(this)
      splash = @battle.getMove("Splash")
      tackle = @battle.getMove("Tackle")
      @p1.moves = [ splash, tackle ]
      lastResort = @battle.getMove("Last Resort")

      mock = @sandbox.mock(lastResort).expects('fail').once()
      @battle.performMove(@p1, lastResort)
      mock.verify()

    it "fails if the pokemon has not used another move since it was active", ->
      shared.create.call(this)
      lastResort = @battle.getMove("Last Resort")
      splash = @battle.getMove("Splash")
      @p1.moves = [ lastResort, splash ]

      mock = @sandbox.mock(lastResort).expects('fail').once()
      @battle.performMove(@p1, lastResort)
      mock.verify()

  describe "Assist", ->
    it "fails if no team member exists", ->
      shared.create.call this,
        team1: [ Factory("Magikarp") ]
      assist = @battle.getMove("Assist")

      mock = @sandbox.mock(assist).expects('fail').once()
      @battle.performMove(@p1, assist)
      mock.verify()

    it "chooses a team member's move at random", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      assist = @battle.getMove("Assist")
      move = @team1.at(1).moves[0]
      shared.biasRNG.call(this, "randInt", "assist", 0)

      mock = @sandbox.mock(move)
      mock.expects('execute').once().withArgs(@battle, @p1, [ @p1 ])
      @battle.performMove(@p1, assist)
      mock.verify()

    it "fails if all team member moves are illegal", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Magikarp") ]
      assist = @battle.getMove("Assist")
      @team1.at(1).moves = []
      @team1.at(1).moves.push @battle.getMove("Assist")
      @team1.at(1).moves.push @battle.getMove("Bestow")
      @team1.at(1).moves.push @battle.getMove("Chatter")
      @team1.at(1).moves.push @battle.getMove("Circle Throw")
      @team1.at(1).moves.push @battle.getMove("Copycat")
      @team1.at(1).moves.push @battle.getMove("Counter")
      @team1.at(1).moves.push @battle.getMove("Covet")
      @team1.at(1).moves.push @battle.getMove("Destiny Bond")
      @team1.at(1).moves.push @battle.getMove("Detect")
      @team1.at(1).moves.push @battle.getMove("Dragon Tail")
      @team1.at(1).moves.push @battle.getMove("Endure")
      @team1.at(1).moves.push @battle.getMove("Feint")
      @team1.at(1).moves.push @battle.getMove("Focus Punch")
      @team1.at(1).moves.push @battle.getMove("Follow Me")
      @team1.at(1).moves.push @battle.getMove("Helping Hand")
      @team1.at(1).moves.push @battle.getMove("Me First")
      @team1.at(1).moves.push @battle.getMove("Metronome")
      @team1.at(1).moves.push @battle.getMove("Mimic")
      @team1.at(1).moves.push @battle.getMove("Mirror Coat")
      @team1.at(1).moves.push @battle.getMove("Mirror Move")
      @team1.at(1).moves.push @battle.getMove("Nature Power")
      @team1.at(1).moves.push @battle.getMove("Protect")
      @team1.at(1).moves.push @battle.getMove("Rage Powder")
      @team1.at(1).moves.push @battle.getMove("Sketch")
      @team1.at(1).moves.push @battle.getMove("Sleep Talk")
      @team1.at(1).moves.push @battle.getMove("Snatch")
      @team1.at(1).moves.push @battle.getMove("Struggle")
      @team1.at(1).moves.push @battle.getMove("Switcheroo")
      @team1.at(1).moves.push @battle.getMove("Thief")
      @team1.at(1).moves.push @battle.getMove("Transform")
      @team1.at(1).moves.push @battle.getMove("Trick")

      mock = @sandbox.mock(assist).expects('fail').once()
      @battle.performMove(@p1, assist)
      mock.verify()

  describe "Metronome", ->
    it "chooses a random move to execute", ->
      shared.create.call(this)
      @p1.moves = []
      metronome = @battle.getMove("Metronome")
      tackle = @battle.getMove("Tackle")
      index = @battle.MoveList.indexOf(tackle)
      shared.biasRNG.call(this, 'randInt', "metronome", index)

      mock = @sandbox.mock(tackle).expects('execute').once()
      @battle.performMove(@p1, metronome)
      mock.verify()

    it "reselects if chosen an illegal move", ->
      shared.create.call(this)
      @p1.moves = [ metronome ]
      metronome = @battle.getMove("Metronome")
      technoBlast = @battle.getMove("Techno Blast")
      tackle = @battle.getMove("Tackle")
      index = @battle.MoveList.indexOf(technoBlast)
      reselectIndex = @battle.MoveList.indexOf(tackle)
      shared.biasRNG.call(this, 'randInt', "metronome", index)
      shared.biasRNG.call(this, 'randInt', "metronome reselect", reselectIndex)

      mock = @sandbox.mock(tackle).expects('execute').once()
      @battle.performMove(@p1, metronome)
      mock.verify()

  describe "Magic Coat", ->
    shared.shouldDoNoDamage("Magic Coat")

    it "causes certain moves directed at the user to be bounced back", ->
      shared.create.call(this)
      whirlwind = @battle.getMove("Whirlwind")
      magicCoat = @battle.getMove("Magic Coat")

      spy = @sandbox.spy(whirlwind, 'execute')
      @battle.performMove(@p1, magicCoat)
      @battle.performMove(@p2, whirlwind)
      spy.args.some((array) =>
        [battle, user, targets] = array
        battle == @battle && user == @p1 && targets[0] == @p2
      ).should.be.true

    it "bounces back spikes", ->
      shared.create.call(this)
      spikes = @battle.getMove("Spikes")
      magicCoat = @battle.getMove("Magic Coat")

      spy = @sandbox.spy(spikes, 'execute')
      @battle.performMove(@p1, magicCoat)
      @battle.performMove(@p2, spikes)
      spy.args.some((array) =>
        [battle, user, targets] = array
        battle == @battle && user == @p1 && targets[0] == @id2
      ).should.be.true
      @team1.has(Attachment.Spikes).should.be.false
      @team2.has(Attachment.Spikes).should.be.true

    it "cannot bounce spikes more than once", ->
      shared.create.call(this)
      spikes = @battle.getMove("Spikes")
      magicCoat = @battle.getMove("Magic Coat")

      @battle.performMove(@p1, magicCoat)
      @battle.performMove(@p2, magicCoat)

      (=>
        @battle.performMove(@p2, spikes)
      ).should.not.throw(/Maximum call stack size exceeded/)

    it "does not bounce certain moves back", ->
      shared.create.call(this)
      tackle = @battle.getMove("Tackle")
      magicCoat = @battle.getMove("Magic Coat")

      spy = @sandbox.spy(tackle, 'execute')
      @battle.performMove(@p1, magicCoat)
      @battle.performMove(@p2, tackle)
      spy.args.some((array) =>
        [battle, user, targets] = array
        battle == @battle && user == @p1 && targets[0] == @p2
      ).should.be.false

    it "lasts until the end of the turn", ->
      shared.create.call(this)
      magicCoat = @battle.getMove("Magic Coat")

      @battle.performMove(@p1, magicCoat)
      @p1.has(Attachment.MagicCoat).should.be.true
      @battle.endTurn()
      @p1.has(Attachment.MagicCoat).should.be.false

    it "cannot bounce more than once in the same turn", ->
      shared.create.call(this)
      willOWisp = @battle.getMove("Will-O-Wisp")
      thunderWave = @battle.getMove("Thunder Wave")
      magicCoat = @battle.getMove("Magic Coat")

      @battle.performMove(@p1, magicCoat)
      @battle.performMove(@p2, willOWisp)

      spy = @sandbox.spy(thunderWave, 'execute')
      @battle.performMove(@p2, thunderWave)
      spy.args.some((array) =>
        [battle, user, targets] = array
        battle == @battle && user == @p1 && targets[0] == @p2
      ).should.be.false

    it "cannot bounce a certain move more than once in the same turn", ->
      shared.create.call(this)
      willOWisp = @battle.getMove("Will-O-Wisp")
      magicCoat = @battle.getMove("Magic Coat")

      @battle.performMove(@p1, magicCoat)
      @battle.performMove(@p2, magicCoat)

      spy = @sandbox.spy(willOWisp, 'execute')
      (=>
        @battle.performMove(@p2, willOWisp)
      ).should.not.throw(/Maximum call stack size exceeded/)
      spy.calledTwice.should.be.true
      spy.args.some((array) =>
        [battle, user, targets] = array
        battle == @battle && user == @p1 && targets[0] == @p2
      ).should.be.true
      spy.args.some((array) =>
        [battle, user, targets] = array
        battle == @battle && user == @p2 && targets[0] == @p1
      ).should.be.true

  describe "Telekinesis", ->
    shared.shouldDoNoDamage("Telekinesis")
    shared.shouldFailIfUsedTwice("Telekinesis")

    it "makes the target immune to ground moves", ->
      shared.create.call(this)
      telekinesis = @battle.getMove("Telekinesis")

      @p1.isImmune('Ground').should.be.false
      @battle.performMove(@p2, telekinesis)
      @p1.isImmune('Ground').should.be.true

    it "lasts 3 turns", ->
      shared.create.call(this)
      telekinesis = @battle.getMove("Telekinesis")

      @battle.performMove(@p2, telekinesis)
      for x in [0...3]
        @p1.isImmune('Ground').should.be.true
        @battle.endTurn()
      @p1.isImmune('Ground').should.be.false

    it "makes the target unable to avoid any attacks", ->
      shared.create.call(this)
      telekinesis = @battle.getMove("Telekinesis")
      tackle = @battle.getMove("Tackle")
      shared.biasRNG.call(this, 'randInt', "miss", 101)  # Always misses

      tackle.willMiss(@battle, @p2, @p1).should.be.true
      @battle.performMove(@p2, telekinesis)
      tackle.willMiss(@battle, @p2, @p1).should.be.false

  describe "Smack Down", ->
    it "doesn't crash on secondary effect", ->
      shared.create.call(this, team2: [ Factory("Gyarados") ])
      shared.biasRNG.call(this, "next", "secondary effect", 0)
      smackDown = @battle.getMove("Smack Down")
      (=> @battle.performMove(@p1, smackDown)).should.not.throw()

    it "removes target's Ground immunity", ->
      shared.create.call(this, team2: [ Factory("Gyarados") ])
      smackDown = @battle.getMove("Smack Down")

      @p2.isImmune("Ground").should.be.true
      @battle.performMove(@p1, smackDown)
      @p2.isImmune("Ground").should.be.false

    it "stops Fly", ->
      shared.create.call(this)
      smackDown = @battle.getMove("Smack Down")
      fly = @battle.getMove("Fly")

      @battle.recordMove(@id1, fly)
      @battle.continueTurn()

      @p1.has(Attachment.Charging).should.be.true
      @battle.performMove(@p2, smackDown)
      @p1.has(Attachment.Charging).should.be.false

    it "stops Bounce", ->
      shared.create.call(this)
      smackDown = @battle.getMove("Smack Down")
      bounce = @battle.getMove("Bounce")

      @battle.recordMove(@id1, bounce)
      @battle.continueTurn()

      @p1.has(Attachment.Charging).should.be.true
      @battle.performMove(@p2, smackDown)
      @p1.has(Attachment.Charging).should.be.false

    it "does not stop other charge moves like Dive", ->
      shared.create.call(this)
      smackDown = @battle.getMove("Smack Down")
      dive = @battle.getMove("Dive")

      @battle.recordMove(@id1, dive)
      @battle.continueTurn()

      @p1.has(Attachment.Charging).should.be.true
      @battle.performMove(@p2, smackDown)
      @p1.has(Attachment.Charging).should.be.true

    it "stops Magnet Rise", ->
      shared.create.call(this)
      smackDown = @battle.getMove("Smack Down")
      magnetRise = @battle.getMove("Magnet Rise")

      @battle.performMove(@p1, magnetRise)

      @p1.has(Attachment.MagnetRise).should.be.true
      @battle.performMove(@p2, smackDown)
      @p1.has(Attachment.MagnetRise).should.be.false

    it "stops Telekinesis", ->
      shared.create.call(this)
      smackDown = @battle.getMove("Smack Down")
      telekinesis = @battle.getMove("Telekinesis")

      @battle.performMove(@p2, telekinesis)

      @p1.has(Attachment.Telekinesis).should.be.true
      @battle.performMove(@p2, smackDown)
      @p1.has(Attachment.Telekinesis).should.be.false

    it "makes Magnet Rise execution fail", ->
      shared.create.call(this)
      smackDown = @battle.getMove("Smack Down")
      magnetRise = @battle.getMove("Magnet Rise")

      @battle.performMove(@p1, smackDown)

      mock = @sandbox.mock(magnetRise).expects('fail').once()
      @battle.performMove(@p2, magnetRise)
      mock.verify()

    it "causes Telekinesis execution to fail", ->
      shared.create.call(this)
      smackDown = @battle.getMove("Smack Down")
      telekinesis = @battle.getMove("Telekinesis")

      @battle.performMove(@p1, smackDown)

      mock = @sandbox.mock(telekinesis).expects('fail').once()
      @battle.performMove(@p1, telekinesis)
      mock.verify()

  describe "Echoed Voice", ->
    it "has 80 base power the second turn in a row it is used", ->
      shared.create.call(this)
      echoedVoice = @battle.getMove("Echoed Voice")

      @battle.performMove(@p1, echoedVoice)
      @battle.endTurn()
      echoedVoice.basePower(@battle, @p1, @p2).should.equal(80)

    it "has 120 base power the third turn in a row it is used", ->
      shared.create.call(this)
      echoedVoice = @battle.getMove("Echoed Voice")

      for i in [1...3]
        @battle.performMove(@p1, echoedVoice)
        @p2.currentHP = @p2.stat('hp')
        @battle.endTurn()
      echoedVoice.basePower(@battle, @p1, @p2).should.equal(120)
    it "has 160 base power the fourth turn in a row it is used", ->
      shared.create.call(this)
      echoedVoice = @battle.getMove("Echoed Voice")

      for i in [1...4]
        @battle.performMove(@p1, echoedVoice)
        @p2.currentHP = @p2.stat('hp')
        @battle.endTurn()
      echoedVoice.basePower(@battle, @p1, @p2).should.equal(160)

    it "has 200 base power the fifth turn in a row it is used", ->
      shared.create.call(this)
      echoedVoice = @battle.getMove("Echoed Voice")

      for i in [1...5]
        @battle.performMove(@p1, echoedVoice)
        @p2.currentHP = @p2.stat('hp')
        @battle.endTurn()
      echoedVoice.basePower(@battle, @p1, @p2).should.equal(200)

    it "has 200 base power the sixth and above turn in a row it is used", ->
      shared.create.call(this)
      echoedVoice = @battle.getMove("Echoed Voice")

      for i in [1...6]
        @battle.performMove(@p1, echoedVoice)
        @p2.currentHP = @p2.stat('hp')
        @battle.endTurn()
      echoedVoice.basePower(@battle, @p1, @p2).should.equal(200)

    it "resets to 40 base power if nobody uses this move the previous turn", ->
      shared.create.call(this)
      echoedVoice = @battle.getMove("Echoed Voice")
      splash = @battle.getMove("Splash")

      @battle.performMove(@p1, echoedVoice)
      @battle.endTurn()
      echoedVoice.basePower(@battle, @p1, @p2).should.equal(80)

      @battle.performMove(@p1, splash)
      @battle.endTurn()
      echoedVoice.basePower(@battle, @p1, @p2).should.equal(40)

    it "has the same base power that turn for all users", ->
      shared.create.call(this)
      echoedVoice = @battle.getMove("Echoed Voice")
      splash = @battle.getMove("Splash")

      @battle.performMove(@p1, echoedVoice)
      @battle.endTurn()
      echoedVoice.basePower(@battle, @p1, @p2).should.equal(80)
      echoedVoice.basePower(@battle, @p2, @p1).should.equal(80)

    it "does not reset even if missing", ->
      shared.create.call(this)
      echoedVoice = @battle.getMove("Echoed Voice")

      @battle.performMove(@p1, echoedVoice)
      @battle.endTurn()
      echoedVoice.basePower(@battle, @p1, @p2).should.equal(80)

      @sandbox.stub(echoedVoice, 'willMiss', -> true)
      @battle.performMove(@p1, echoedVoice)
      @battle.endTurn()
      echoedVoice.basePower(@battle, @p1, @p2).should.equal(120)

  describe "Struggle", ->
    it "deals typless damage", ->
      shared.create.call(this)
      struggle = @battle.getMove('Struggle')

      for type of util.Type
        util.typeEffectiveness(struggle.type, [type]).should.equal(1)

    it "deals 25% in recoil to the attacker, rounded down", ->
      shared.create.call(this)
      struggle = @battle.getMove('Struggle')

      hp = @p1.currentHP
      @p1.currentHP.should.equal @p1.stat('hp')
      @battle.performMove(@p1, struggle)
      (hp - @p1.currentHP).should.equal(hp >> 2)

  describe "Nature Power", ->
    it "uses Earthquake in Wi-Fi battles", ->
      shared.create.call(this)
      naturePower = @battle.getMove('Nature Power')
      earthquake = @battle.getMove('Earthquake')

      mock = @sandbox.mock(earthquake).expects('execute').once()
                                      .withArgs(@battle, @p1, [ @p2 ])
      @battle.performMove(@p1, naturePower)
      mock.verify()

  testRampageMove = (moveName) ->
    describe moveName, ->
      it "lasts 2-3 turns", ->
        shared.create.call(this)
        shared.biasRNG.call(this, 'randInt', 'rampage turns', 2)
        rampageMove = @battle.getMove(moveName)

        @battle.performMove(@p1, rampageMove)
        @p1.has(Attachment.Rampage).should.be.true
        @battle.endTurn()
        @battle.performMove(@p1, rampageMove)
        @battle.endTurn()
        @p1.has(Attachment.Rampage).should.be.false

      it "locks the user into that move until execution ends", ->
        shared.create.call(this)
        shared.biasRNG.call(this, 'randInt', 'rampage turns', 2)
        rampageMove = @battle.getMove(moveName)
        splash = @battle.getMove("Splash")
        @p1.moves = [ rampageMove, splash ]
        @p1.resetAllPP()

        @battle.performMove(@p1, rampageMove)
        @p2.currentHP = @p2.stat('hp')
        @battle.endTurn()
        @battle.beginTurn()
        @p1.validMoves().should.eql [ rampageMove ]

        @battle.performMove(@p1, rampageMove)
        @battle.endTurn()
        @battle.beginTurn()
        @p1.validMoves().should.eql [ rampageMove, splash ]

      it "blocks switching until execution ends", ->
        shared.create.call(this)
        shared.biasRNG.call(this, 'randInt', 'rampage turns', 2)
        rampageMove = @battle.getMove(moveName)

        @battle.performMove(@p1, rampageMove)
        @p2.currentHP = @p2.stat('hp')
        @battle.endTurn()
        @battle.beginTurn()
        @p1.isSwitchBlocked().should.be.true

        @battle.performMove(@p1, rampageMove)
        @battle.endTurn()
        @battle.beginTurn()
        @p1.isSwitchBlocked().should.be.false

      it "confuses the user after use", ->
        shared.create.call(this)
        shared.biasRNG.call(this, 'randInt', 'rampage turns', 2)
        rampageMove = @battle.getMove(moveName)

        @battle.performMove(@p1, rampageMove)
        @p2.currentHP = @p2.stat('hp')
        @battle.endTurn()
        @battle.beginTurn()
        @p1.has(Attachment.Confusion).should.be.false

        @battle.performMove(@p1, rampageMove)
        @battle.endTurn()
        @battle.beginTurn()
        @p1.has(Attachment.Confusion).should.be.true

      it "stops immediately if the user's move did not hit", ->
        shared.create.call(this)
        shared.biasRNG.call(this, 'randInt', 'rampage turns', 3)
        rampageMove = @battle.getMove(moveName)
        protect = @battle.getMove("Protect")

        @battle.performMove(@p1, rampageMove)
        @battle.endTurn()
        @battle.beginTurn()

        @battle.recordMove(@id2, protect)
        @battle.recordMove(@id1, rampageMove)
        @battle.continueTurn()
        @battle.endTurn()
        @p1.has(Attachment.Rampage).should.be.false

  testRampageMove("Outrage")
  testRampageMove("Petal Dance")
  testRampageMove("Thrash")

  test2To5MulthitMove = (moveName) ->
    describe moveName, ->
      it "deals 2 to 5 hits with a probability distribution of 1/3, 1/3, 1/6, 1/6", ->
        shared.create.call(this)

        move = @battle.getMove(moveName)
        spy = @sandbox.spy(@battle.rng, 'choice')
        spy = spy.withArgs([2, 2, 3, 3, 4, 5], 'num hits')

        @battle.performMove(@p1, move)
        spy.calledOnce.should.be.true

      it "hits 5 times if the user has Skill Link", ->
        shared.create.call(this, team1: [Factory('Cloyster', ability: 'Skill Link')])

        # try to "trick" the system into giving an invalid result. It should always hit
        # 5 times regardless of the rng
        shared.biasRNG.call(this, "choice", 'num hits', 2)
        shared.biasRNG.call(this, "randInt", 'num hits', 2)

        move = @battle.getMove(moveName)
        move.calculateNumberOfHits(@battle, @p1, [ @p2 ]).should.equal(5)

      it "only hits up until the target Pokemon faints", ->
        shared.create.call(this, team1: [Factory('Cloyster', ability: 'Skill Link')])

        # try to "trick" the system into giving an invalid result. It should always hit
        # 5 times regardless of the rng
        shared.biasRNG.call(this, "choice", 'num hits', 3)
        shared.biasRNG.call(this, "randInt", 'num hits', 3)

        @p2.currentHP = 1
        move = @battle.getMove(moveName)
        spy = @sandbox.spy(move, 'hit')
        @battle.performMove(@p1, move)
        spy.calledOnce.should.be.true

  test2To5MulthitMove('Arm Thrust')
  test2To5MulthitMove('Barrage')
  test2To5MulthitMove('Bone Rush')
  test2To5MulthitMove('Bullet Seed')
  test2To5MulthitMove('Comet Punch')
  test2To5MulthitMove('DoubleSlap')
  test2To5MulthitMove('Fury Attack')
  test2To5MulthitMove('Fury Swipes')
  test2To5MulthitMove('Icicle Spear')
  test2To5MulthitMove('Pin Missile')
  test2To5MulthitMove('Rock Blast')
  test2To5MulthitMove('Spike Cannon')
  test2To5MulthitMove('Tail Slap')

  describe "Trick Room", ->
    it "lasts 5 turns", ->
      shared.create.call(this)
      trickRoom = @battle.getMove("Trick Room")
      @battle.performMove(@p1, trickRoom)
      for x in [0...5]
        @battle.has(Attachment.TrickRoom).should.be.true
        @battle.endTurn()
      @battle.has(Attachment.TrickRoom).should.be.false

    it "ends a previous use of Trick Room", ->
      shared.create.call(this)
      trickRoom = @battle.getMove("Trick Room")

      @battle.performMove(@p1, trickRoom)
      @battle.has(Attachment.TrickRoom).should.be.true
      @battle.performMove(@p1, trickRoom)
      @battle.has(Attachment.TrickRoom).should.be.false

    it "reverses the order that moves are performed in", ->
      shared.create.call(this, team1: [Factory("Magikarp", evs: {speed: 4})])
      trickRoom = @battle.getMove("Trick Room")
      splash = @battle.getMove("Splash")
      @battle.performMove(@p1, trickRoom)

      @battle.recordMove(@id1, splash)
      @battle.recordMove(@id2, splash)
      @battle.determineTurnOrder().map((o) -> o.pokemon).should.eql [ @p2, @p1 ]

  describe "Transform", ->
    shared.shouldDoNoDamage("Transform")
    shared.shouldFailIfUsedTwice("Transform")

    it "fails on a substitute", ->
      shared.create.call(this)
      substitute = @battle.getMove("Substitute")
      transform = @battle.getMove("Transform")

      @battle.performMove(@p2, substitute)
      mock = @sandbox.mock(transform).expects('fail').once()
      @battle.performMove(@p1, transform)
      mock.verify()

    it "changes the user's type to match the target's", ->
      shared.create.call(this, team2: [Factory("Celebi")])
      transform = @battle.getMove("Transform")

      @battle.performMove(@p1, transform)
      @p1.types.should.eql @p2.types

    it "forces a sprite change", ->
      shared.create.call(this, team2: [Factory("Celebi")])
      transform = @battle.getMove("Transform")

      mock = @sandbox.mock(@p1).expects('changeSprite').once()
      @battle.performMove(@p1, transform)
      mock.verify()

    it "does not change species or forme", ->
      shared.create.call(this, team2: [Factory("Latias")])
      transform = @battle.getMove("Transform")

      oldSpecies = @p1.species
      oldForme = @p1.forme
      @battle.performMove(@p1, transform)
      @p1.species.should.equal(oldSpecies)
      @p1.forme.should.equal(oldForme)

    it "changes the user's stats to match the target's, except HP", ->
      shared.create.call(this, team2: [Factory("Celebi", evs: {speed: 252})])
      transform = @battle.getMove("Transform")

      @battle.performMove(@p1, transform)
      for stat of @p2.baseStats
        if stat == 'hp'
          @p1.stat(stat).should.not.equal(@p2.stat(stat))
        else
          @p1.stat(stat).should.equal(@p2.stat(stat))

    it "copies the target's gender", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "F")]
        team2: [Factory("Celebi")]
      transform = @battle.getMove("Transform")

      @battle.performMove(@p1, transform)
      @p1.gender.should.equal(@p2.gender)

    it "copies the target's moveset, setting each PP and max PP to 5", ->
      shared.create.call(this, team2: [Factory("Celebi")])
      transform = @battle.getMove("Transform")
      @p2.boost(attack: 3, speed: -2, accuracy: 1)

      @battle.performMove(@p1, transform)
      @p1.moves.should.eql @p2.moves
      for move in @p1.moves
        @p1.pp(move).should.equal(5)
        @p1.maxPP(move).should.equal(5)

    it "copies the target's stat boosts", ->
      shared.create.call(this, team2: [Factory("Celebi")])
      transform = @battle.getMove("Transform")
      @p2.boost(attack: 3, speed: -2, accuracy: 1)

      @battle.performMove(@p1, transform)
      @p1.stages.should.containEql(attack: 3, speed: -2, accuracy: 1)

    it "copies the target's ability", ->
      shared.create.call this,
        team2: [Factory("Celebi", ability: "Natural Cure")]
      transform = @battle.getMove("Transform")

      @battle.performMove(@p1, transform)
      @p1.hasAbility("Natural Cure").should.be.true

    it "copies the target's weight", ->
      shared.create.call this,
        team2: [Factory("Celebi")]
      transform = @battle.getMove("Transform")

      @battle.performMove(@p1, transform)
      @p1.weight.should.equal(@p2.weight)

    it "copies the target's gender", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "F")]
        team2: [Factory("Celebi")]
      transform = @battle.getMove("Transform")

      @battle.performMove(@p1, transform)
      @p1.gender.should.equal(@p2.gender)

    it "restores the original stats after switching out", ->
      shared.create.call this,
        team1: [Factory("Ditto"), Factory("Magikarp")]
        team2: [Factory("Celebi", ability: "Natural Cure", evs: {speed: 252})]
      transform = @battle.getMove("Transform")
      baseStats = _.clone(@p1.baseStats)
      evs = _.clone(@p1.evs)
      stats = {}
      for stat of baseStats
        stats[stat] = @p1.stat(stat)

      @battle.performMove(@p1, transform)
      @p1.baseStats.should.not.eql(baseStats)
      @p1.evs.should.not.eql(evs)
      for stat, value of stats
        @p1.stat(stat).should.not.equal(value)

      @battle.performSwitch(@p1, 1)
      @p1.baseStats.should.eql(baseStats)
      @p1.evs.should.eql(evs)
      for stat, value of stats
        @p1.stat(stat).should.equal(value)

    it "restores the original species and type after switching out", ->
      shared.create.call this,
        team1: [Factory("Ditto"), Factory("Magikarp")]
        team2: [Factory("Celebi", ability: "Natural Cure")]
      transform = @battle.getMove("Transform")
      species = @p1.species
      types = _.clone(@p1.types)
      @battle.performMove(@p1, transform)
      @battle.performSwitch(@team1.first(), 1)
      @p1.types.should.eql(types)
      @p1.species.should.eql(species)

    it "restores the original ability after switching out", ->
      # Ditto has a fake ability so we can test abilities being restored.
      shared.create.call this,
        team1: [Factory("Ditto", ability: "Sniper"), Factory("Magikarp")]
        team2: [Factory("Celebi", ability: "Natural Cure")]
      transform = @battle.getMove("Transform")
      ability = @p1.ability
      @battle.performMove(@p1, transform)
      @battle.performSwitch(@team1.first(), 1)
      @p1.ability.should.eql(ability)

    it "restores original moveset after switch, but Transform PP decreases", ->
      shared.create.call this,
        team1: [Factory("Ditto"), Factory("Magikarp")]
        team2: [Factory("Celebi", ability: "Natural Cure")]
      transform = @battle.getMove("Transform")
      moves = _.clone(@p1.moves)
      ppHash = _.clone(@p1.ppHash)
      maxPPHash = _.clone(@p1.maxPPHash)
      @battle.performMove(@p1, transform)
      @battle.performSwitch(@team1.first(), 1)
      @p1.moves.should.eql(moves)
      @p1.maxPPHash.should.eql(maxPPHash)
      # Transform's PP should go down!
      ppHash[transform.name] -= 1
      @p1.ppHash.should.eql(ppHash)

    it "restores original gender after switch", ->
      shared.create.call this,
        team1: [Factory("Ditto"), Factory("Magikarp")]
        team2: [Factory("Celebi", ability: "Natural Cure")]
      transform = @battle.getMove("Transform")
      gender = @p1.gender
      @battle.performMove(@p1, transform)
      @battle.performSwitch(@team1.first(), 1)
      @p1.gender.should.eql(gender)

    it "restores original weight after switch", ->
      shared.create.call this,
        team1: [Factory("Ditto"), Factory("Magikarp")]
        team2: [Factory("Celebi", ability: "Natural Cure")]
      transform = @battle.getMove("Transform")
      weight = @p1.weight
      @battle.performMove(@p1, transform)
      @battle.performSwitch(@team1.first(), 1)
      @p1.weight.should.eql(weight)

    it "fails if the target is transformed", ->
      shared.create.call(this)
      transform = @battle.getMove("Transform")

      @battle.performMove(@p2, transform)
      mock = @sandbox.mock(transform).expects('fail').once()
      @battle.performMove(@p1, transform)
      mock.verify()

    it "fails if the target is under an illusion"
    it "fails if the user is under an illusion"
    it "cannot change formes if it has the ability to do so"

  describe "Fling", ->
    it "fails if the pokemon has no item", ->
      shared.create.call(this)
      fling = @battle.getMove("Fling")
      mock = @sandbox.mock(fling).expects('fail').once()
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      mock.verify()

    it "fails if the item is not removeable", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Acro Bike")]
      fling = @battle.getMove("Fling")
      mock = @sandbox.mock(fling).expects('fail').once()
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      mock.verify()

    it "fails if the user is blocked from using items", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Armor Fossil")]
      fling = @battle.getMove("Fling")
      @p1.blockItem()
      mock = @sandbox.mock(fling).expects('fail').once()
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      mock.verify()

    it "has a base power depending on the item held", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Armor Fossil")]
      fling = @battle.getMove("Fling")
      fling.beforeTurn(@battle, @p1)
      @p1.beforeMove(fling, @p1, [@p2])
      fling.basePower(@battle, @p1, @p2).should.equal(100)

    it "inflicts Burn on the target if Flame Orb is held", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Flame Orb")]
      fling = @battle.getMove("Fling")
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      @p2.has(Status.Burn).should.be.true

    it "inflicts Toxic on the target if Toxic Orb is held", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Toxic Orb")]
      fling = @battle.getMove("Fling")
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      @p2.has(Status.Toxic).should.be.true

    it "flinches the target if King's Rock is held", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "King's Rock")]
      fling = @battle.getMove("Fling")
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      @p2.has(Attachment.Flinch).should.be.true

    it "flinches the target if Razor Fang is held", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Razor Fang")]
      fling = @battle.getMove("Fling")
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      @p2.has(Attachment.Flinch).should.be.true

    it "paralyzes the target if Light Ball is held", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Light Ball")]
      fling = @battle.getMove("Fling")
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      @p2.has(Status.Paralyze).should.be.true

    it "removes negative status effects if Mental Herb is held", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Mental Herb")]
      fling = @battle.getMove("Fling")
      @p2.attach(Attachment.Torment)
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      @p2.has(Attachment.Torment).should.be.false

    it "removes negative stat boosts if White Herb is held", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "White Herb")]
      fling = @battle.getMove("Fling")
      @p2.boost(attack: 1, accuracy: -2)
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      @p2.stages.should.containEql(attack: 1, accuracy: 0)

    it "inflicts Poison on the target if Poison Barb is held", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Poison Barb")]
      fling = @battle.getMove("Fling")
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      @p2.has(Status.Poison).should.be.true

    it "causes target to eat the flung berry if a berry is held", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry")]
      fling = @battle.getMove("Fling")
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      @p2.stages.speed.should.equal(1)

    it "does not activate an item effect when hitting a substitute", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Toxic Orb")]
      fling = @battle.getMove("Fling")
      @p2.attach(Attachment.Substitute, hp: 1)
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      @p2.has(Status.Toxic).should.be.false

    it "loses the user's item", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Poison Barb")]
      fling = @battle.getMove("Fling")
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      @p1.hasItem().should.be.false

    it "loses the item even if execution is canceled by protect", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Poison Herb")]
      protect = @battle.getMove("Protect")
      fling = @battle.getMove("Fling")
      mock = @sandbox.mock(fling).expects('hit').never()
      @battle.recordMove(@id2, protect)
      @battle.recordMove(@id1, fling)
      @battle.continueTurn()
      mock.verify()
      @p1.hasItem().should.be.false

  describe "Bug Bite", ->
    it "eats the target's berry and gets its effects", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Salac Berry")]
      bugBite = @battle.getMove("Bug Bite")
      @battle.performMove(@p1, bugBite)
      @p2.hasItem().should.be.false
      @p1.stages.should.containEql(speed: 1)

    it "does eat the target's berry if the target fainted", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Salac Berry")]
      bugBite = @battle.getMove("Bug Bite")
      @p2.currentHP = 1
      @battle.performMove(@p1, bugBite)
      @p2.isFainted().should.be.true
      @p1.stages.should.containEql(speed: 1)

    it "does not eat the target's berry if the user fainted", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Salac Berry", ability: "Iron Barbs")]
      bugBite = @battle.getMove("Bug Bite")
      @p1.currentHP = 1
      @battle.performMove(@p1, bugBite)
      @p1.isFainted().should.be.true
      @p2.hasItem().should.be.true

  describe "Beat Up", ->
    it "deals 1 less hit for each unhealthy member in the user's party", ->
      shared.create.call this,
        team1: (Factory("Magikarp")  for i in [0...6])
      @team1.at(5).attach(Status.Paralyze)
      @team1.at(1).faint()
      beatUp = @battle.getMove("Beat Up")
      mock = @sandbox.mock(beatUp).expects('hit').exactly(4)
      @battle.performMove(@p1, beatUp)
      mock.verify()

    it "has 5 + X/10 base power for X in team, where X is base attack", ->
      shared.create.call this,
        team1: [  Factory("Magikarp"), Factory("Scyther"), Factory("Celebi"),
                  Factory("Totodile"), Factory("Rayquaza"), Factory("Seedot") ]
      beatUp = @battle.getMove("Beat Up")
      spy = @sandbox.spy(beatUp, "basePower")
      @battle.performMove(@p1, beatUp)
      for pokemon in @team1.pokemon
        basePower = 5 + Math.floor(pokemon.baseStats.attack / 10)
        spy.returned(basePower).should.be.true

    it "works for teams smaller than 6", ->
      shared.create.call this,
        team1: (Factory("Magikarp")  for i in [0...4])
      beatUp = @battle.getMove("Beat Up")
      mock = @sandbox.mock(beatUp).expects('hit').exactly(4)
      @battle.performMove(@p1, beatUp)
      mock.verify()

    it "doesn't crash if all pokemon are statused or fainted", ->
      shared.create.call this,
        team1: (Factory("Magikarp")  for i in [0...2])
      @team1.at(1).faint()
      @team1.at(0).attach(Status.Burn)
      beatUp = @battle.getMove("Beat Up")
      (=>
        @battle.performMove(@p1, beatUp)
      ).should.not.throw()

    it "doesn't crash when used by a pokemon with technician", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Technician")])
      beatUp = @battle.getMove("Beat Up")
      (=>
        @battle.performMove(@p1, beatUp)
      ).should.not.throw()

  describe "Psycho Shift", ->
    it "fails if the user doesn't have a status", ->
      shared.create.call(this)
      psychoShift = @battle.getMove("Psycho Shift")
      mock = @sandbox.mock(psychoShift).expects('fail').once()
      @battle.performMove(@p1, psychoShift)
      mock.verify()

    it "fails if the target already has a status", ->
      shared.create.call(this)
      @p1.attach(Status.Toxic)
      @p2.attach(Status.Paralyze)
      psychoShift = @battle.getMove("Psycho Shift")
      mock = @sandbox.mock(psychoShift).expects('fail').once()
      @battle.performMove(@p1, psychoShift)
      mock.verify()

    it "cures the user of its status", ->
      shared.create.call(this)
      @p1.attach(Status.Poison)
      psychoShift = @battle.getMove("Psycho Shift")
      @battle.performMove(@p1, psychoShift)
      @p1.hasStatus().should.be.false

    it "gives the user's former status to the target", ->
      shared.create.call(this)
      @p1.attach(Status.Burn)
      psychoShift = @battle.getMove("Psycho Shift")
      @battle.performMove(@p1, psychoShift)
      @p2.has(Status.Burn).should.be.true

  describe "Gravity", ->
    shared.shouldDoNoDamage("Gravity")
    shared.shouldFailIfUsedTwice("Gravity")

    it "raises accuracy of all attacks by 5/3", ->
      shared.create.call(this)
      gravity = @battle.getMove("Gravity")
      focusBlast = @battle.getMove("Focus Blast")
      @battle.performMove(@p1, gravity)
      accuracy = focusBlast.chanceToHit(@battle, @p1, @p2)
      accuracy.should.equal Math.floor(focusBlast.accuracy * 5 / 3)

    it "lasts 5 turns", ->
      shared.create.call(this)
      gravity = @battle.getMove("Gravity")
      @battle.performMove(@p1, gravity)
      for i in [0...5]
        @battle.has(Attachment.Gravity).should.be.true
        @battle.endTurn()
      @battle.has(Attachment.Gravity).should.be.false

    it "makes Flying Pokemon no longer immune to Ground", ->
      shared.create.call(this)
      @p2.types = [ "Flying" ]
      @p2.isImmune("Ground").should.be.true
      gravity = @battle.getMove("Gravity")
      @battle.performMove(@p1, gravity)
      @p2.isImmune("Ground").should.be.false

    it "makes Levitating Pokemon no longer immune to Ground", ->
      shared.create.call(this, team2: [Factory("Magikarp", ability: "Levitate")])
      @p2.isImmune("Ground").should.be.true
      gravity = @battle.getMove("Gravity")
      @battle.performMove(@p1, gravity)
      @p2.isImmune("Ground").should.be.false

    it "deals damage to Flying Pokemon", ->
      shared.create.call(this)
      @p2.types = [ "Flying" ]
      gravity = @battle.getMove("Gravity")
      earthquake = @battle.getMove("Earthquake")
      earthquake.typeEffectiveness(@battle, @p1, @p2).should.equal(0)
      @battle.performMove(@p1, gravity)
      earthquake.typeEffectiveness(@battle, @p1, @p2).should.equal(1)

    # TODO: Sky Drop
    for moveName in [ "Bounce", "Fly" ]
      do (moveName) ->
        it "grounds pokemon using #{moveName}", ->
          shared.create.call(this)
          move = @battle.getMove(moveName)
          gravity = @battle.getMove("Gravity")
          @battle.recordMove(@id2, move)
          @battle.continueTurn()
          @p2.has(Attachment.Charging).should.be.true

          @battle.recordMove(@id1, gravity)
          @battle.continueTurn()
          @p2.has(Attachment.Charging).should.be.false

    it "removes Telekinesis", ->
      shared.create.call(this)
      telekinesis = @battle.getMove("Telekinesis")
      gravity = @battle.getMove("Gravity")
      @battle.performMove(@p1, telekinesis)
      @p2.has(Attachment.Telekinesis).should.be.true
      @battle.performMove(@p1, gravity)
      @p2.has(Attachment.Telekinesis).should.be.false

    it "removes Magnet Rise", ->
      shared.create.call(this)
      magnetRise = @battle.getMove("Magnet Rise")
      gravity = @battle.getMove("Gravity")
      @battle.performMove(@p2, magnetRise)
      @p2.has(Attachment.MagnetRise).should.be.true
      @battle.performMove(@p1, gravity)
      @p2.has(Attachment.MagnetRise).should.be.false

    for moveName in [ "Jump Kick", "Hi Jump Kick", "Bounce", "Fly", "Sky Drop",
                      "Splash", "Telekinesis" ]
      do (moveName) ->
        it "disables #{moveName}", ->
          shared.create.call(this)
          move = @battle.getMove(moveName)
          gravity = @battle.getMove("Gravity")
          @p1.moves = [ move ]
          @p2.moves = [ move ]
          @battle.performMove(@p1, gravity)
          @battle.beginTurn()
          @p1.validMoves().should.not.containEql(move)
          @p2.validMoves().should.not.containEql(move)

        it "prevents the execution of #{moveName}", ->
          shared.create.call(this)
          move = @battle.getMove(moveName)
          gravity = @battle.getMove("Gravity")
          @battle.performMove(@p1, gravity)
          mock = @sandbox.mock(move).expects('execute').never()
          @battle.performMove(@p2, move)
          mock.verify()

  testDelayedAttackMove = (moveName, type) ->
    describe moveName, ->
      shared.shouldFailIfUsedTwice(moveName)

      it "waits three turns before attacking", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)
        for x in [0...3]
          @p2.currentHP.should.equal @p2.stat('hp')
          @battle.endTurn()
        @p2.currentHP.should.be.lessThan @p2.stat('hp')

      it "does not initialize and error if the target has fainted", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)
        @p2.faint()
        (=> @battle.performMove(@p1, move)).should.not.throw()

      it "does not hit if the target has fainted", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)
        for x in [0...2]
          @battle.endTurn()
        @p2.faint()
        mock = @sandbox.mock(move).expects('hit').never()
        @battle.endTurn()
        mock.verify()

      it "is considered a direct attack", ->
        shared.create.call(this)
        move = @battle.getMove(moveName)
        @battle.performMove(@p1, move)
        @p2.attach(Attachment.Substitute, hp: 1)
        @battle.endTurn()
        @battle.endTurn()
        @p2.has(Attachment.Substitute).should.be.true
        @battle.endTurn()
        @p2.has(Attachment.Substitute).should.be.false

      it "can target multiple positions"

  testDelayedAttackMove("Future Sight")
  testDelayedAttackMove("Doom Desire")

  describe "Baton Pass", ->
    it "fails if there is no benched pokemon to BP to", ->
      shared.create.call(this, team1: [Factory('Magikarp')])
      batonPass = @battle.getMove("Baton Pass")
      mock = @sandbox.mock(batonPass).expects('fail').once()
      @battle.performMove(@p1, batonPass)
      mock.verify()

    it "switches to another pokemon", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Celebi") ]
      batonPass = @battle.getMove("Baton Pass")
      @battle.performMove(@p1, batonPass)
      @battle.requests.should.have.property @id1

    it "passes certain attachments to the next pokemon", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Celebi") ]
      batonPass = @battle.getMove("Baton Pass")
      @p1.attach(Attachment.Ingrain)
      @p1.attach(Attachment.Torment)
      @battle.performMove(@p1, batonPass)
      @battle.performSwitch(@team1.first(), 1)
      @team1.first().has(Attachment.Torment).should.be.false
      @team1.first().has(Attachment.Ingrain).should.be.true

    it "continues Perish Song's counter", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Celebi") ]
      batonPass = @battle.getMove("Baton Pass")
      perishSong = @battle.getMove("Perish Song")
      @battle.performMove(@p1, perishSong)
      for i in [0...3]
        @battle.endTurn()
      @battle.performMove(@p1, batonPass)
      @battle.performSwitch(@team1.first(), 1)
      @team1.first().isFainted().should.be.false
      @battle.endTurn()
      @team1.first().isFainted().should.be.true

    it "passes status boosts to the next pokemon", ->
      shared.create.call this,
        team1: [ Factory("Magikarp"), Factory("Celebi") ]
      batonPass = @battle.getMove("Baton Pass")
      @p1.boost(attack: 1, evasion: -3)
      @battle.performMove(@p1, batonPass)
      @battle.performSwitch(@team1.first(), 1)
      @team1.first().stages.should.containEql(attack: 1, evasion: -3)

  describe "Thunder Wave", ->
    it "is affected by immunities", ->
      shared.create.call(this)
      thunderWave = @battle.getMove("Thunder Wave")
      @p2.types = [ 'Ground' ]
      @battle.performMove(@p1, thunderWave)
      @p2.has(Status.Paralyze).should.be.false

  describe "Thunder", ->
    it "has 50% accuracy in Sun", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SUN)
      thunder = @battle.getMove("Thunder")
      thunder.chanceToHit(@battle, @p1, @p2).should.equal(50)

    it "has perfect accuracy in Rain", ->
      shared.create.call(this)
      @battle.setWeather(Weather.RAIN)
      thunder = @battle.getMove("Thunder")
      thunder.chanceToHit(@battle, @p1, @p2).should.equal(0)

    it "has normal accuracy otherwise", ->
      shared.create.call(this)
      @battle.setWeather(Weather.HAIL)
      thunder = @battle.getMove("Thunder")
      thunder.chanceToHit(@battle, @p1, @p2).should.equal(70)

  describe "Hurricane", ->
    it "has 50% accuracy in Sun", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SUN)
      hurricane = @battle.getMove("Hurricane")
      hurricane.chanceToHit(@battle, @p1, @p2).should.equal(50)

    it "has perfect accuracy in Rain", ->
      shared.create.call(this)
      @battle.setWeather(Weather.RAIN)
      hurricane = @battle.getMove("Hurricane")
      hurricane.chanceToHit(@battle, @p1, @p2).should.equal(0)

    it "has normal accuracy otherwise", ->
      shared.create.call(this)
      @battle.setWeather(Weather.HAIL)
      hurricane = @battle.getMove("Hurricane")
      hurricane.chanceToHit(@battle, @p1, @p2).should.equal(70)

  describe "Blizzard", ->
    it "has perfect accuracy in Hail", ->
      shared.create.call(this)
      @battle.setWeather(Weather.HAIL)
      blizzard = @battle.getMove("Blizzard")
      blizzard.chanceToHit(@battle, @p1, @p2).should.equal(0)

    it "has normal accuracy otherwise", ->
      shared.create.call(this)
      blizzard = @battle.getMove("Blizzard")
      blizzard.chanceToHit(@battle, @p1, @p2).should.equal(70)

  describe "Sleep Talk", ->
    it "fails if the pokemon is awake", ->
      shared.create.call(this)
      sleepTalk = @battle.getMove("Sleep Talk")
      mock = @sandbox.mock(sleepTalk).expects('fail').once()
      @battle.performMove(@p1, sleepTalk)
      mock.verify()

    it "performs a random move when the pokemon is asleep", ->
      shared.create.call(this)
      shared.biasRNG.call(this, 'randInt', 'sleep talk', 0)
      tackle = @battle.getMove("Tackle")
      sleepTalk = @battle.getMove("Sleep Talk")
      @p1.moves = [ tackle, sleepTalk ]
      @p1.resetAllPP()
      @p1.attach(Status.Sleep)
      spy = @sandbox.spy(@battle, 'executeMove')
      @battle.performMove(@p1, sleepTalk)
      spy.calledWith(tackle).should.be.true

    it "does not choose sleep talk or other moves", ->
      shared.create.call(this)
      shared.biasRNG.call(this, 'randInt', 'sleep talk', 0)
      tackle = @battle.getMove("Tackle")
      sleepTalk = @battle.getMove("Sleep Talk")
      assist = @battle.getMove("Assist")
      @p1.moves = [ sleepTalk, assist, tackle ]
      @p1.resetAllPP()
      @p1.attach(Status.Sleep)
      spy = @sandbox.spy(@battle, 'executeMove')
      @battle.performMove(@p1, sleepTalk)
      spy.calledWith(tackle).should.be.true

    it "fails if there are no viable moves", ->
      shared.create.call(this)
      shared.biasRNG.call(this, 'randInt', 'sleep talk', 0)
      sleepTalk = @battle.getMove("Sleep Talk")
      @p1.moves = [ sleepTalk ]
      @p1.resetAllPP()
      @p1.attach(Status.Sleep)
      mock = @sandbox.mock(sleepTalk).expects('fail').once()
      @battle.performMove(@p1, sleepTalk)
      mock.verify()

    it "changes the move's target properly", ->
      shared.create.call(this)
      shared.biasRNG.call(this, 'randInt', 'sleep talk', 0)
      tackle = @battle.getMove("Tackle")
      sleepTalk = @battle.getMove("Sleep Talk")
      @p1.moves = [ tackle, sleepTalk ]
      @p1.resetAllPP()
      @p1.attach(Status.Sleep)

      mock = @sandbox.mock(tackle)
      mock.expects('execute').once().withArgs(@battle, @p1, [ @p2 ])
      @battle.performMove(@p1, sleepTalk)
      mock.verify()

  describe "Rest", ->
    it "fails if the pokemon is at full HP", ->
      shared.create.call(this)
      rest = @battle.getMove("Rest")
      mock = @sandbox.mock(rest).expects('fail').once()

      @p1.setHP(@p1.stat('hp'))
      @battle.performMove(@p1, rest)
      mock.verify()

    it "restores the pokemon to full HP otherwise", ->
      shared.create.call(this)
      rest = @battle.getMove("Rest")

      @p1.setHP(1)
      @battle.performMove(@p1, rest)
      @p1.currentHP.should.equal @p1.stat('hp')

    it "sleeps the pokemon", ->
      shared.create.call(this)
      rest = @battle.getMove("Rest")

      @p1.setHP(1)
      @p1.has(Status.Sleep).should.be.false
      @battle.performMove(@p1, rest)
      @p1.has(Status.Sleep).should.be.true

    it "fails if the pokemon is already asleep", ->
      shared.create.call(this)
      rest = @battle.getMove("Rest")
      mock = @sandbox.mock(rest).expects('fail').once()

      @p1.setHP(1)
      @p1.attach(Status.Sleep)
      # execute instead of perform to avoid beforeMove callbacks.
      @battle.executeMove(rest, @p1, [ @p1 ])
      mock.verify()

    it "cures the pokemon of adverse status effects", ->
      shared.create.call(this)
      rest = @battle.getMove("Rest")

      @p1.setHP(1)
      @p1.attach(Status.Burn)
      @p1.has(Status.Burn).should.be.true
      @battle.performMove(@p1, rest)
      @p1.has(Status.Sleep).should.be.true
      @p1.has(Status.Burn).should.be.false

    it "always forces sleep turns to be 2", ->
      shared.create.call(this)
      shared.biasRNG.call(this, "randInt", "sleep turns", 3)
      rest = @battle.getMove("Rest")

      @p1.setHP(1)
      @battle.performMove(@p1, rest)
      attachment = @p1.get(Status.Sleep)
      should.exist(attachment)
      attachment.should.have.property("turns")
      attachment.turns.should.equal(2)

    it "fails if the Pokemon cannot be slept", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Vital Spirit")]
      rest = @battle.getMove("Rest")
      mock = @sandbox.mock(rest).expects('fail').once()

      @p1.setHP(1)
      @battle.performMove(@p1, rest)
      mock.verify()

  describe "Defog", ->
    it "lowers target's evasion by 1", ->
      shared.create.call(this, gen: 'bw')
      defog = @battle.getMove("Defog")
      @battle.performMove(@p1, defog)
      @p2.stages.should.containEql(evasion: -1)

    it "removes Reflect on target's side", ->
      shared.create.call(this, gen: 'bw')
      defog = @battle.getMove("Defog")
      @battle.performMove(@p2, @battle.getMove("Reflect"))
      @p2.team.has(Attachment.Reflect).should.be.true
      @battle.performMove(@p1, defog)
      @p2.team.has(Attachment.Reflect).should.be.false

    it "removes Light Screen on target's side", ->
      shared.create.call(this, gen: 'bw')
      defog = @battle.getMove("Defog")
      @battle.performMove(@p2, @battle.getMove("Light Screen"))
      @p2.team.has(Attachment.LightScreen).should.be.true
      @battle.performMove(@p1, defog)
      @p2.team.has(Attachment.LightScreen).should.be.false

    it "removes Spikes on target's side", ->
      shared.create.call(this, gen: 'bw')
      defog = @battle.getMove("Defog")
      @battle.performMove(@p1, @battle.getMove("Spikes"))
      @p2.team.has(Attachment.Spikes).should.be.true
      @battle.performMove(@p1, defog)
      @p2.team.has(Attachment.Spikes).should.be.false

    it "removes Stealth Rock on target's side", ->
      shared.create.call(this, gen: 'bw')
      defog = @battle.getMove("Defog")
      @battle.performMove(@p1, @battle.getMove("Stealth Rock"))
      @p2.team.has(Attachment.StealthRock).should.be.true
      @battle.performMove(@p1, defog)
      @p2.team.has(Attachment.StealthRock).should.be.false

    it "removes Toxic Spikes on target's side", ->
      shared.create.call(this, gen: 'bw')
      defog = @battle.getMove("Defog")
      @battle.performMove(@p1, @battle.getMove("Toxic Spikes"))
      @p2.team.has(Attachment.ToxicSpikes).should.be.true
      @battle.performMove(@p1, defog)
      @p2.team.has(Attachment.ToxicSpikes).should.be.false

    it "removes Safeguard on target's side", ->
      shared.create.call(this, gen: 'bw')
      defog = @battle.getMove("Defog")
      @battle.performMove(@p2, @battle.getMove("Safeguard"))
      @p2.team.has(Attachment.Safeguard).should.be.true
      @battle.performMove(@p1, defog)
      @p2.team.has(Attachment.Safeguard).should.be.false

    it "removes Mist on target's side"

  describe "Refresh", ->
    it "fails if the Pokemon has no status", ->
      shared.create.call(this, gen: 'bw')
      refresh = @battle.getMove("Refresh")
      mock = @sandbox.mock(refresh).expects('fail').once()
      @battle.performMove(@p1, refresh)
      mock.verify()

    it "restores a Pokemon's status", ->
      shared.create.call(this, gen: 'bw')
      refresh = @battle.getMove("Refresh")
      @p1.attach(Status.Burn)
      @p1.has(Status.Burn).should.be.true
      @battle.performMove(@p1, refresh)
      @p1.has(Status.Burn).should.be.false

    it "sends a message about status being restored", ->
      shared.create.call(this, gen: 'bw')
      refresh = @battle.getMove("Refresh")
      @p1.attach(Status.Burn)
      spy = @sandbox.spy(@battle, 'message')
      @battle.performMove(@p1, refresh)
      spy.args.join(',').should.containEql("#{@p1.name} healed its burn!")

  describe "Growth", ->
    it "boosts the pokemon's stats", ->
      shared.create.call(this, gen: 'bw')
      @battle.setWeather(Weather.SUN)
      @battle.performMove(@p1, @battle.getMove('Growth'))
      @p1.stages.should.containEql attack: 2, specialAttack: 2

  describe "Reflect Type", ->
    it "copies the target's types", ->
      shared.create.call(this, team1: [Factory("Magikarp")], team2: [Factory("Charmander")])
      @battle.performMove(@p1, @battle.getMove('Reflect Type'))
      @p1.types.should.containEql "Fire"

    it "fails if the user has multitype", ->
      shared.create.call(this, team1: [Factory("Arceus", ability: "Multitype")], team2: [Factory("Toxicroak")])
      @battle.performMove(@p1, @battle.getMove('Reflect Type'))
      @p1.types.should.containEql "Normal"

  describe "Retaliate", ->
    it "doubles in power if a pokemon on the user's side fainted last turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp"), Factory("Slaking")]
      @p2.currentHP = 1
      @battle.beginTurn()
      @battle.recordMove(@id1, @battle.getMove("Aqua Jet"))
      @battle.recordMove(@id2, @battle.getMove("Splash"))
      @battle.continueTurn()
      @battle.endTurn()
      @battle.beginTurn()

      retaliate = @battle.getMove("Retaliate")
      spy = @sandbox.spy(retaliate, 'basePower')
      @battle.performMove(@p2, retaliate)
      spy.returned(140).should.be.true

    it "deals normal damage otherwise", ->
      shared.create.call(this)

      retaliate = @battle.getMove("Retaliate")
      spy = @sandbox.spy(retaliate, 'basePower')
      @battle.performMove(@p1, retaliate)
      spy.returned(70).should.be.true

  describe "Role Play", ->
    it "copies the target's ability", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Swift Swim")]
        team2: [Factory("Magikarp", ability: "Levitate")]
      @battle.performMove(@p1, @battle.getMove('Role Play'))
      @p1.hasAbility("Levitate").should.be.true

    it "does not copy certain abilities", ->
      shared.create.call this,
        team1: [Factory("Magikarp"), ability: "Swift Swim"]
        team2: [Factory("Arceus", ability: "Multitype")]
      @battle.performMove(@p1, @battle.getMove('Role Play'))
      @p1.hasAbility("Multitype").should.be.false

  describe "Relic Song", ->
    it "transforms Meloetta", ->
      shared.create.call this,
        team1: [Factory("Meloetta")]
        team2: [Factory("Arceus")]
      @battle.performMove(@p1, @battle.getMove('Relic Song'))
      @p1.forme.should.equal("pirouette")
      @battle.performMove(@p1, @battle.getMove('Relic Song'))
      @p1.forme.should.equal("default")

    it "changes Meloetta to default forme after switching out", ->
      shared.create.call this,
        team1: [Factory("Meloetta"), Factory("Magikarp")]
        team2: [Factory("Arceus")]
      @battle.performMove(@p1, @battle.getMove('Relic Song'))
      @p1.forme.should.equal("pirouette")
      @battle.performSwitch(@p1, 1)
      @battle.performSwitch(@team1.first(), 1)
      @p1.forme.should.equal("default")

    it "does not transform Pokemon that are not Meloetta", ->
      shared.create.call this,
        team1: [Factory("Smeargle")]
        team2: [Factory("Magikarp")]
      @p1.forme.should.equal("default")
      @battle.performMove(@p1, @battle.getMove('Relic Song'))
      @p1.forme.should.equal("default")

  describe "Safeguard", ->
    it "protects the user's team from status", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Safeguard"))
      @battle.performMove(@p2, @battle.getMove("Thunder Wave"))
      @p1.has(Status.Paralyze).should.be.false

    it "protects the user's team from confusion", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Safeguard"))
      @battle.performMove(@p2, @battle.getMove("Confuse Ray"))
      @p1.has(Attachment.Confusion).should.be.false

    it "doesn't protect against status inflicted by the user", ->
      shared.create.call(this)
      @p1.team.attach(Attachment.Safeguard)
      @p1.setHP(1)
      @battle.performMove(@p1, @battle.getMove("Rest"))
      @p1.has(Status.Sleep).should.be.true

    it "protects against yawn being inflicted", ->
      shared.create.call(this)
      @p1.team.attach(Attachment.Safeguard)
      @battle.performMove(@p2, @battle.getMove("Yawn"))
      @p1.has(Attachment.Yawn).should.be.false

    it "doesn't prevent yawn's effect", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove('Yawn'))
      @battle.endTurn()
      @p2.has(Status.Sleep).should.be.false
      @p2.team.attach(Attachment.Safeguard)
      @battle.endTurn()
      @p2.has(Status.Sleep).should.be.true

  describe "Soak", ->
    it "changes the target's type to Water", ->
      shared.create.call this,
        team1: [Factory("Magikarp")]
        team2: [Factory("Smeargle")]
      @p2.types.should.not.eql ['Water']
      @battle.performMove(@p1, @battle.getMove('Soak'))
      @p2.types.should.eql ['Water']

    it "does not affect pure Water type Pokemon", ->
      shared.create.call this,
        team1: [Factory("Smeargle")]
        team2: [Factory("Magikarp")]
      @p2.types.should.eql ['Water']
      soak = @battle.getMove("Soak")
      mock = @sandbox.mock(soak).expects('fail').once()
      @battle.performMove(@p1, soak)
      mock.verify()

    it "does not affect Arceus", ->
      shared.create.call this,
        team1: [Factory("Smeargle")]
        team2: [Factory("Arceus")]
      soak = @battle.getMove("Soak")
      mock = @sandbox.mock(soak).expects('fail').once()
      @battle.performMove(@p1, soak)
      mock.verify()

  describe 'Electro Ball', ->
    it 'has variable base power based on speed of user and target', ->
      shared.create.call this,
        team1: [Factory('Electrode', evs: {speed: 252}, nature: "Timid")]
        team2: [Factory('Smeargle')]
      move = @battle.getMove('Electro Ball')
      move.basePower(@battle, @p1, @p2).should.equal 80

  describe "Snore", ->
    it "fails if the pokemon is awake", ->
      shared.create.call(this)
      snore = @battle.getMove("Snore")
      mock = @sandbox.mock(snore).expects('fail').once()
      @battle.performMove(@p1, snore)
      mock.verify()

    it "attacks the target when the user is asleep", ->
      shared.create.call this,
      snore = @battle.getMove("Snore")
      @p1.attach(Status.Sleep)
      mock = @sandbox.mock(snore).expects('hit').once()
      @battle.performMove(@p1, snore)
      mock.verify()

  describe "Worry Seed", ->
    it "changes the target's ability to Insomnia", ->
      shared.create.call this,
        team1: [Factory("Smeargle")]
        team2: [Factory("Magikarp", ability: "Swift Swim")]
      @battle.performMove(@p1, @battle.getMove('Worry Seed'))
      @p2.hasAbility("Insomnia").should.be.true

    it "does not change some abilities", ->
      shared.create.call this,
        team1: [Factory("Smeargle")]
        team2: [Factory("Arceus", ability: "Multitype")]
      worrySeed = @battle.getMove("Worry Seed")
      mock = @sandbox.mock(worrySeed).expects('fail').once()
      @battle.performMove(@p1, worrySeed)
      mock.verify()

  describe "Simple Beam", ->
    it "changes the target's ability to Simple", ->
      shared.create.call this,
        team1: [Factory("Smeargle")]
        team2: [Factory("Magikarp", ability: "Swift Swim")]
      @battle.performMove(@p1, @battle.getMove('Simple Beam'))
      @p2.hasAbility("Simple").should.be.true

    it "does not change some abilities", ->
      shared.create.call this,
        team1: [Factory("Smeargle")]
        team2: [Factory("Arceus", ability: "Multitype")]
      simpleBeam = @battle.getMove("Simple Beam")
      mock = @sandbox.mock(simpleBeam).expects('fail').once()
      @battle.performMove(@p1, simpleBeam)
      mock.verify()

  describe "Entrainment", ->
    it "copies the user's ability to the target", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Swift Swim")]
        team2: [Factory("Smeargle", ability: "Own Tempo")]
      @battle.performMove(@p1, @battle.getMove('Entrainment'))
      @p2.hasAbility("Swift Swim").should.be.true

    it "does not copy some abilities", ->
      shared.create.call this,
        team1: [Factory("Arceus", ability: "Multitype")]
        team2: [Factory("Magikarp", ability: "Swift Swim")]
      entrainment = @battle.getMove("Entrainment")
      mock = @sandbox.mock(entrainment).expects('fail').once()
      @battle.performMove(@p1, entrainment)
      mock.verify()

  describe "Natural Gift", ->
    it "changes power and type depending on the berry held by the user", ->
      shared.create.call this,
        team1: [Factory("Smeargle", item: 'Liechi Berry')]
        team2: [Factory("Magikarp")]
      move = @battle.getMove('Natural Gift')
      basePower = move.basePower(@battle, @p1, @p2)
      basePower.should.equal(80)
      move.typeEffectiveness(@battle, @p1, @p2).should.equal(2)

    it "only works with certain items", ->
      shared.create.call this,
        team1: [Factory("Smeargle", item: 'Leftovers')]
      naturalGift = @battle.getMove('Natural Gift')
      mock = @sandbox.mock(naturalGift).expects('fail').once()
      @battle.performMove(@p1, naturalGift)
      mock.verify()

    it "should remove the item even if missing"

  describe "False Swipe", ->
    it "leaves the target with at least 1 HP", ->
      shared.create.call(this)
      @p2.currentHP = 1
      @battle.performMove(@p1, @battle.getMove("False Swipe"))
      @p2.currentHP.should.equal 1

    it "does normal damage if the target has a substitute", ->
      shared.create.call(this)
      @p2.currentHP = 1
      @p2.attach(Attachment.Substitute)
      falseSwipe = @battle.getMove("False Swipe")
      spy = @sandbox.spy(falseSwipe, 'calculateDamage')
      @battle.performMove(@p1, falseSwipe)
      spy.returned(0).should.be.false

  describe "Gastro Acid", ->
    it "suppresses the target's ability", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Gastro Acid"))
      @p2.has(Attachment.AbilitySuppress).should.be.true
      @p2.isAbilityBlocked().should.be.true

    it "continues turn by turn", ->
      shared.create.call(this)
      @battle.performMove(@p1, @battle.getMove("Gastro Acid"))
      @battle.endTurn()
      @battle.beginTurn()
      @p2.has(Attachment.AbilitySuppress).should.be.true
      @p2.isAbilityBlocked().should.be.true

    it "fails against some abilities", ->
      shared.create.call(this, team2: [Factory("Arceus", ability: "Multitype")])
      gastroAcid = @battle.getMove("Gastro Acid")
      mock = @sandbox.mock(gastroAcid).expects('fail').once()
      @battle.performMove(@p1, gastroAcid)
      mock.verify()

  describe "Helping Hand", ->
    it "fails if there is no target", ->
      shared.create.call(this)
      helpingHand = @battle.getMove("Helping Hand")
      mock = @sandbox.mock(helpingHand).expects('fail').once()
      @battle.performMove(@p1, helpingHand)
      mock.verify()

  describe "Skill Swap", ->
    it "swaps the user's ability with the target's", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Swift Swim")]
        team2: [Factory("Smeargle", ability: "Own Tempo")]
      @battle.performMove(@p1, @battle.getMove('Skill Swap'))
      @p1.hasAbility("Own Tempo").should.be.true
      @p2.hasAbility("Swift Swim").should.be.true

    it "cannot swap some abilities", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Swift Swim")]
        team2: [Factory("Shedinja", ability: "Wonder Guard")]
      skillSwap = @battle.getMove("Skill Swap")
      mock = @sandbox.mock(skillSwap).expects('fail').once()
      @battle.performMove(@p1, skillSwap)
      mock.verify()

    it "cannot swap the abilities if they are the same", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Swift Swim")]
        team2: [Factory("Magikarp", ability: "Swift Swim")]
      skillSwap = @battle.getMove("Skill Swap")
      mock = @sandbox.mock(skillSwap).expects('fail').once()
      @battle.performMove(@p1, skillSwap)
      mock.verify()

    it "activates abilities after swapping", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Swift Swim")]
        team2: [Factory("Gyarados", ability: "Intimidate")]
      @battle.performMove(@p1, @battle.getMove('Skill Swap'))
      @p1.hasAbility("Intimidate").should.be.true
      @p2.hasAbility("Swift Swim").should.be.true
      @p2.stages.should.containEql(attack: -1)

  describe "Heal Block", ->
    it "lasts 5 turns", ->
      shared.create.call(this)
      healBlock = @battle.getMove("Heal Block")
      @battle.performMove(@p1, healBlock)
      for x in [0...5]
        @p2.has(Attachment.HealBlock).should.be.true
        @battle.endTurn()
      @p2.has(Attachment.HealBlock).should.be.false

    it 'prevents the target from executing a healing move', ->
      shared.create.call(this, team1: [ Factory('Magikarp', evs: {speed: 4}) ])
      move = @battle.getMove('Recover')
      healBlock = @battle.getMove('Heal Block')
      mock = @sandbox.mock(move)
      mock.expects('execute').never()

      @battle.performMove(@p1, healBlock)
      @battle.performMove(@p2, move)

      mock.verify()

    it 'prevents the target from selecting a healing move', ->
      shared.create.call this,
        team2: [Factory("Magikarp", moves: [ "Splash", "Recover" ])]

      @battle.performMove(@p1, @battle.getMove('Heal Block'))
      @battle.beginTurn()
      requestedMoves = @battle.requestFor(@p2).moves
      requestedMoves.should.not.containEql 'Recover'

    it "prevents Abilities that heal from healing", ->
      shared.create.call this,
        team2: [Factory("Magikarp", ability: "Water Absorb")]
      @p2.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Heal Block'))
      @battle.endTurn()
      @battle.performMove(@p1, @battle.getMove('Water Gun'))
      @p2.currentHP.should.equal 1

    it "does not prevent Regenerator from healing", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Regenerator")]
      @p1.currentHP = 1
      @battle.performMove(@p2, @battle.getMove('Heal Block'))
      @p1.switchOut(@battle)
      hp = Math.floor(@p1.stat('hp') / 3)
      @p1.currentHP.should.equal(1 + hp)

    it "prevents items that heal from healing", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Leftovers")]
      @p2.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Heal Block'))
      @battle.endTurn()
      @p2.currentHP.should.equal 1

    it "prevents Berries that heal from attempting to activate", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Sitrus Berry")]
      item = @p2.item
      hp = @p2.currentHP
      @p2.currentHP >>= 1
      @battle.performMove(@p1, @battle.getMove('Heal Block'))
      @battle.endTurn()
      @battle.performMove(@p1, @battle.getMove('Tackle'))
      @p2.currentHP.should.be.lessThan hp >> 1
      @p2.item.should.equal item
