sinon = require 'sinon'
{items, moves} = require('../data/bw')
{Battle, Pokemon, Status, VolatileStatus, ParalyzeAttachment} = require('../').server
{Factory} = require './factory'
should = require 'should'
{_} = require 'underscore'
shared = require './shared'

describe 'Mechanics', ->
  describe 'splash', ->
    shared.shouldDoNoDamage('Splash')

  describe 'an attack missing', ->
    it 'deals no damage', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Magikarp')]
      move = moves['leaf-storm']
      sinon.stub(move, 'willMiss', -> true)
      defender = @team2.at(0)
      originalHP = defender.currentHP
      @battle.makeMove(@player1, 'leaf-storm')
      @battle.continueTurn()
      defender.currentHP.should.equal originalHP
      move.willMiss.restore()

    it 'triggers effects dependent on the move missing', ->
      shared.create.call this,
        team1: [Factory('Hitmonlee')]
        team2: [Factory('Magikarp')]
      move = moves['hi-jump-kick']
      sinon.stub(move, 'willMiss', -> true)
      mock = sinon.mock(move)
      mock.expects('afterMiss').once()
      originalHP = @team1.at(0).currentHP
      @battle.makeMove(@player1, 'hi-jump-kick')
      @battle.continueTurn()
      mock.verify()
      mock.restore()
      move.willMiss.restore()

    it 'does not trigger effects dependent on the move hitting', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      move = moves['hi-jump-kick']
      sinon.stub(move, 'willMiss', -> true)
      mock = sinon.mock(move)
      mock.expects('afterSuccessfulHit').never()
      @battle.makeMove(@player1, 'leaf-storm')
      @battle.continueTurn()
      mock.verify()
      mock.restore()
      move.willMiss.restore()

  describe 'an attack with 0 accuracy', ->
    it 'can never miss', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'aerial-ace')
      @battle.continueTurn()
      @team2.at(0).currentHP.should.be.below hp

  describe 'accuracy and evasion boosts', ->
    it 'heighten and lower the chances of a move hitting', ->
      shared.create.call this,
        team1: [Factory('Hitmonlee')]
        team2: [Factory('Magikarp')]
      @battle.rng.randInt.restore()
      sinon.stub(@battle.rng, 'randInt', -> 50)

      move = moves['mach-punch']
      mock = sinon.mock(move).expects('afterMiss').once()
      @team2.at(0).boost(evasion: 6)
      @battle.makeMove(@player1, 'mach-punch')
      @battle.continueTurn()
      mock.verify()
      move.afterMiss.restore()

      mock = sinon.mock(move).expects('afterSuccessfulHit').once()
      @team1.at(0).boost(accuracy: 6)
      @battle.makeMove(@player1, 'mach-punch')
      @battle.continueTurn()
      mock.verify()
      move.afterSuccessfulHit.restore()

  describe 'fainting', ->
    it 'forces a new pokemon to be picked', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @team2.at(0).currentHP = 1
      spy = sinon.spy(@player2, 'emit')
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      spy.calledWith('request action').should.be.true

    it 'does not increment the turn count', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      turn = @battle.turn
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      @battle.turn.should.not.equal turn + 1

    it 'removes the fainted pokemon from the action priority queue', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      turn = @battle.turn
      @team1.at(0).currentHP = 1
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      @team1.at(0).currentHP.should.be.below 1
      @team2.at(0).currentHP.should.equal 1

    it 'lets the player switch in a new pokemon', ->
      shared.create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      @battle.makeSwitchByName(@player2, 'Heracross')
      @team2.at(0).name.should.equal 'Heracross'

  describe 'secondary effect attacks', ->
    it 'can inflict effect on successful hit', ->
      shared.create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Porygon-Z')]
      @battle.rng.next.restore()
      sinon.stub(@battle.rng, 'next', -> 0)     # 100% chance
      defender = @team2.at(0)
      @battle.makeMove(@player1, 'flamethrower')
      @battle.continueTurn()
      defender.hasStatus(Status.BURN).should.be.true

  describe 'the fang attacks', ->
    it 'can inflict two effects at the same time', ->
      shared.create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Gyarados')]
      @battle.rng.next.restore()
      sinon.stub(@battle.rng, 'next', -> 0)     # 100% chance
      defender = @team2.at(0)
      @battle.makeMove(@player1, 'ice-fang')
      @battle.continueTurn()
      defender.hasAttachment(VolatileStatus.FLINCH).should.be.true
      defender.hasStatus(Status.FREEZE).should.be.true

  describe 'jump kick attacks', ->
    it 'has 50% recoil if it misses', ->
      shared.create.call this,
        team1: [Factory('Hitmonlee')]
        team2: [Factory('Magikarp')]
      move = moves['hi-jump-kick']
      sinon.stub(move, 'willMiss', -> true)
      originalHP = @team1.at(0).currentHP
      @battle.makeMove(@player1, 'hi-jump-kick')
      @battle.continueTurn()
      damage = 312
      (originalHP - @team1.at(0).currentHP).should.equal Math.floor(damage / 2)
      move.willMiss.restore()

  describe 'drain attacks', ->
    it 'recovers a percentage of the damage dealt, rounded down', ->
      shared.create.call this,
        team1: [Factory('Conkeldurr')]
        team2: [Factory('Hitmonchan')]
      startHP = 1
      @team1.at(0).currentHP = startHP
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'drain-punch')
      @battle.continueTurn()
      damage = (hp - @team2.at(0).currentHP)
      (@team1.at(0).currentHP - startHP).should.equal Math.floor(damage / 2)

    it 'cannot recover to over 100% HP', ->
      shared.create.call this,
        team1: [Factory('Conkeldurr')]
        team2: [Factory('Hitmonchan')]
      hp = @team1.at(0).currentHP = @team1.at(0).stat('hp')
      @battle.makeMove(@player1, 'drain-punch')
      @battle.continueTurn()
      (@team1.at(0).currentHP - hp).should.equal 0

  describe 'weight-based attacks', ->
    it 'has 80 base power if the pokemon is 50.2kg', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Hitmonchan')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'grass-knot')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 94

    it 'has 120 base power if the pokemon is >200kg', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'grass-knot')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 153

  describe 'a pokemon using a primary boosting move', ->
    it "doesn't do damage if base power is 0", ->
      shared.create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Hitmonchan')]
      @battle.makeMove(@player1, 'dragon-dance')
      @battle.continueTurn()
      @team2.at(0).currentHP.should.equal @team2.at(0).stat('hp')

    it "boosts the pokemon's stats", ->
      shared.create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Hitmonchan')]
      attack = @team1.at(0).stat('attack')
      speed  = @team1.at(0).stat('speed')
      @battle.makeMove(@player1, 'dragon-dance')
      @battle.continueTurn()
      @team1.at(0).stages.should.include attack: 1, speed: 1

    it "affects type-immune pokemon", ->
      shared.create.call this,
        team1: [Factory('Audino')]
        team2: [Factory('Gengar')]
      @battle.makeMove(@player1, 'Growl')
      @battle.makeMove(@player2, 'Shadow Ball')
      @team2.at(0).stages.attack.should.equal -1

    it "has the boosts removed on switch"

  describe 'a pokemon using a damaging move that also boosts stats on hit', ->
    it "deals damage and boosts stats", ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'leaf-storm')
      @battle.continueTurn()
      @team1.at(0).stages.specialAttack.should.equal -2
      (hp - @team2.at(0).currentHP).should.equal 178

  describe 'a pokemon using a move with a secondary boosting effect', ->
    it "has a chance to activate", ->
      shared.create.call this,
        team1: [Factory('Mew')]
        team2: [Factory('Hitmonchan')]
      @battle.rng.next.restore()
      sinon.stub(@battle.rng, 'next', -> 0)     # 100% chance
      attack = @team1.at(0).stat('attack')
      speed  = @team1.at(0).stat('speed')
      @battle.makeMove(@player1, 'ancientpower')
      @battle.continueTurn()
      @team1.at(0).stages.should.include {
        attack: 1, defense: 1, speed: 1, specialAttack: 1, specialDefense: 1
      }

  describe 'a pokemon using Acrobatics', ->
    it 'gets double the base power without an item', ->
      shared.create.call this,
        team1: [Factory('Gliscor')]
        team2: [Factory('Regirock')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'acrobatics')
      @battle.continueTurn()
      damage = (hp - @team2.at(0).currentHP)
      damage.should.equal 36

    it 'has normal base power with an item', ->
      shared.create.call this,
        team1: [Factory('Gliscor', item: 'Leftovers')]
        team2: [Factory('Regirock')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'acrobatics')
      @battle.continueTurn()
      damage = (hp - @team2.at(0).currentHP)
      damage.should.equal 18

  describe 'a pokemon using a standard recoil move', ->
    it 'receives a percentage of the damage rounded down', ->
      shared.create.call this,
        team1: [Factory('Blaziken')]
        team2: [Factory('Gliscor')]
      startHP = @team1.at(0).currentHP
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'brave-bird')
      @battle.continueTurn()
      damage = (hp - @team2.at(0).currentHP)
      (startHP - @team1.at(0).currentHP).should.equal Math.floor(damage / 3)

  describe 'a pokemon with technician', ->
    it "doesn't increase damage if the move has bp > 60", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @battle.makeMove(@player1, 'Ice Punch')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 84

    it "increases damage if the move has bp <= 60", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Shaymin (land)')]
      @battle.makeMove(@player1, 'Bullet Punch')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 67

  describe 'STAB', ->
    it "gets applied if the move and user share a type", ->
      shared.create.call this,
        team1: [Factory('Heracross')]
        team2: [Factory('Regirock')]
      @battle.makeMove(@player1, 'Megahorn')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 123

    it "doesn't get applied if the move and user are of different types", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @battle.makeMove(@player1, 'Ice Punch')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 84

    it 'is 2x if the pokemon has Adaptability', ->
      shared.create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Mew')]
      @battle.makeMove(@player1, 'Tri Attack')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 214

  describe 'turn order', ->
    it 'randomly decides winner if pokemon have the same speed and priority', ->
      shared.create.call this,
        team1: [Factory('Mew')]
        team2: [Factory('Mew')]
      spy = sinon.spy(@battle, 'orderIds')
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Psychic')
      spy.returned([@id2, @id1]).should.be.true
      @battle.rng.next.restore()

      sinon.stub(@battle.rng, 'next', -> .4)
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Psychic')
      spy.returned([@id1, @id2]).should.be.true

    it 'decides winner by highest priority move', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Hitmonchan')]
      spy = sinon.spy(@battle, 'orderIds')
      @battle.makeMove(@player1, 'Mach Punch')
      @battle.makeMove(@player2, 'ThunderPunch')
      spy.returned([@id1, @id2]).should.be.true
      @battle.rng.next.restore()

      @battle.makeMove(@player1, 'ThunderPunch')
      @battle.makeMove(@player2, 'Mach Punch')
      spy.returned([@id2, @id1]).should.be.true

    it 'decides winner by speed if priority is equal', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Hitmonchan')]
      spy = sinon.spy(@battle, 'orderIds')
      @battle.makeMove(@player1, 'ThunderPunch')
      @battle.makeMove(@player2, 'ThunderPunch')
      spy.returned([@id2, @id1]).should.be.true

  describe 'fainting all the opposing pokemon', ->
    it "doesn't request any more actions from players", ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Mach Punch')
      @battle.makeMove(@player2, 'Psychic')
      @battle.requests.should.not.have.property @player1.id
      @battle.requests.should.not.have.property @player2.id

    it 'ends the battle', ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @team2.at(0).currentHP = 1
      mock = sinon.mock(@battle)
      mock.expects('endBattle').once()
      @battle.makeMove(@player1, 'Mach Punch')
      @battle.makeMove(@player2, 'Psychic')
      mock.verify()

  describe 'a pokemon using a hazing move', ->
    shared.shouldDoNoDamage('Haze')

    it 'removes all status boosts from each pokemon', ->
      shared.create.call this,
        team1: [Factory('Weezing')]
        team2: [Factory('Mew')]
      # shared.Create artificial boosts.
      @team1.at(0).stages.attack = 2
      @team1.at(0).stages.evasion = -1
      @team2.at(0).stages.defense = -3
      @team2.at(0).stages.specialAttack = 4
      @battle.makeMove(@player1, 'Haze')
      @battle.continueTurn()
      neutralBoosts = {
        attack: 0, defense: 0, specialAttack: 0, specialDefense: 0,
        speed: 0, evasion: 0, accuracy: 0
      }
      @team1.at(0).stages.should.eql neutralBoosts
      @team2.at(0).stages.should.eql neutralBoosts

  describe 'Seismic Toss and Night Shade', ->
    it 'does exactly the same damage as their level', ->
      shared.create.call this,
        team1: [Factory('Blissey')]
        team2: [Factory('Mew')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'Seismic Toss')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 100

  describe 'Psywave', ->
    it 'does user.level/2 damage minimum', ->
      shared.create.call this,
        team1: [Factory('Weezing')]
        team2: [Factory('Mew')]
      move = moves['psywave']
      @battle.rng.randInt.restore()
      @battle.rng.next.restore()
      sinon.stub(@battle.rng, 'next', -> 0)
      sinon.stub(move, 'willMiss', -> false)
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'Psywave')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 50
      move.willMiss.restore()

    it 'does user.level * 1.5 damage maximum', ->
      shared.create.call this,
        team1: [Factory('Weezing')]
        team2: [Factory('Mew')]
      move = moves['psywave']
      @battle.rng.randInt.restore()
      @battle.rng.next.restore()
      sinon.stub(@battle.rng, 'next', -> .999)
      sinon.stub(move, 'willMiss', -> false)
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'Psywave')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 150
      move.willMiss.restore()

    it 'rounds down to the nearest .1 multiplier', ->
      shared.create.call this,
        team1: [Factory('Weezing')]
        team2: [Factory('Mew')]
      move = moves['psywave']
      @battle.rng.randInt.restore()
      @battle.rng.next.restore()
      sinon.stub(@battle.rng, 'next', -> .11)
      sinon.stub(move, 'willMiss', -> false)
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'Psywave')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 60
      move.willMiss.restore()

  describe 'facade', ->
    it 'doubles the base power if burned, poisoned, or paralyzed', ->
      shared.create.call this,
        team1: [Factory('Zangoose')]
        team2: [Factory('Magikarp')]
      hp = @team2.at(0).currentHP
      @team1.at(0).attach(new ParalyzeAttachment())
      @battle.makeMove(@player1, 'Facade')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 324

  describe 'reversal and flail', ->
    it 'have 200 base power at 1 hp', ->
      shared.create.call this,
        team1: [Factory('Zangoose')]
        team2: [Factory('Magikarp')]
      @team1.at(0).currentHP = 1
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'Flail')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 462

    it 'have 40 base power at 50% hp', ->
      shared.create.call this,
        team1: [Factory('Zangoose')]
        team2: [Factory('Magikarp')]
      @team1.at(0).currentHP = Math.floor(@team1.at(0).stat('hp') / 2)
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'Flail')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 94

  describe 'eruption and water spout', ->
    beforeEach ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Mew')]
      @attacker = @team1.at(0)
      @defender = @team2.at(0)
      @move = moves['eruption']

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
      move = moves['gyro-ball']
      attacker = @team1.at(0)
      defender = @team2.at(0)
      attacker.stages.speed = -6
      move.basePower(@battle, attacker, defender).should.equal 150

    it 'has variable base power based on speed of target and user', ->
      shared.create.call this,
        team1: [Factory('Electrode', evs: {speed: 252}, nature: "Jolly")]
        team2: [Factory('Magikarp', ivs: {speed: 0})]
      move = moves['gyro-ball']
      attacker = @team1.at(0)
      defender = @team2.at(0)
      attacker.stages.speed = -6
      move.basePower(@battle, attacker, defender).should.equal 40

  describe 'brine', ->
    it 'has normal base power if the target has over 50% HP', ->
      shared.create.call this,
        team1: [Factory('Empoleon')]
        team2: [Factory('Magikarp')]
      move = moves['brine']
      @team2.at(0).currentHP = Math.floor(@team2.at(0).currentHP / 2) + 1
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 65

    it 'doubles base power if the target has 50% or less HP', ->
      shared.create.call this,
        team1: [Factory('Empoleon')]
        team2: [Factory('Magikarp')]
      move = moves['brine']
      @team2.at(0).currentHP = Math.floor(@team2.at(0).currentHP / 2)
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 130

  describe 'yawn', ->
    shared.shouldDoNoDamage('Yawn')

    it 'gives the yawn attachment', ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Magikarp')]
      @battle.makeMove(@player1, 'Yawn')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).hasAttachment('YawnAttachment').should.be.true

    it 'puts the opponent to sleep at the end of the second turn', ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Magikarp')]
      @battle.makeMove(@player1, 'Yawn')
      @battle.makeMove(@player2, 'Splash')

      @battle.makeMove(@player1, 'Yawn')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).hasStatus(Status.SLEEP).should.be.true
      @battle.turn.should.equal 3

    it 'does not put the opponent to sleep at the end of the first turn', ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Magikarp')]
      @battle.makeMove(@player1, 'Yawn')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).hasStatus(Status.SLEEP).should.be.false
      @battle.turn.should.equal 2

  describe 'a pokemon with a type immunity', ->
    it 'cannot be damaged by a move of that type', ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Gyarados')]
      @battle.makeMove(@player1, 'Earthquake')
      @battle.makeMove(@player2, 'Dragon Dance')

      @team2.at(0).currentHP.should.equal @team2.at(0).stat('hp')

  describe 'an OHKO move', ->
    it 'ignores accuracy/evasion modifiers', ->
      @team1.at(0).stages.accuracy = -6
      @team2.at(0).stages.evasion = 6
      acc = moves['sheer-cold'].chanceToHit(@battle, @team1.at(0), @team2.at(0))

      acc.should.equal 30

    it "does damage equal to the target's total hp", ->
      shared.create.call this,
        team1: [Factory('Lapras')]
        team2: [Factory('Magikarp')]
      hpDiff = -1
      @team2.at(0).currentHP += hpDiff
      @battle.makeMove(@player1, 'Sheer Cold')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).currentHP.should.equal hpDiff

  describe 'a recovery move', ->
    shared.shouldDoNoDamage('Recover')

    it "recovers 50% of the target's HP", ->
      shared.create.call this,
        team1: [Factory('Blissey')]
        team2: [Factory('Magikarp')]
      hp = @team1.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Softboiled')
      @battle.makeMove(@player2, 'Splash')

      recoverHP = Math.floor(@team1.at(0).stat('hp') / 2)
      (@team1.at(0).currentHP - hp).should.equal recoverHP

  describe 'knock off', ->
    it "deals damage", ->
      shared.create.call this,
        team1: [Factory('Drapion')]
        team2: [Factory('Magikarp', item: "Leftovers")]
      @battle.makeMove(@player1, 'Knock Off')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).currentHP.should.be.lessThan @team2.at(0).stat('hp')

    it "removes the target's item", ->
      shared.create.call this,
        team1: [Factory('Drapion')]
        team2: [Factory('Magikarp', item: "Leftovers")]
      @battle.makeMove(@player1, 'Knock Off')
      @battle.makeMove(@player2, 'Splash')

      should.not.exist @team2.at(0).item

  describe 'trick and switcheroo', ->
    shared.shouldDoNoDamage('Trick')

    it "isn't affected by type-immunities", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Stick')]
        team2: [Factory('Drapion', item: "Leftovers")]
      item1 = @team1.at(0).item
      item2 = @team2.at(0).item
      @battle.makeMove(@player1, 'Trick')
      @battle.makeMove(@player2, 'Swords Dance')

      @team2.at(0).item.should.equal item1
      @team1.at(0).item.should.equal item2

    it "swaps the target and user's item", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Stick')]
        team2: [Factory('Magikarp', item: "Leftovers")]
      item1 = @team1.at(0).item
      item2 = @team2.at(0).item
      @battle.makeMove(@player1, 'Trick')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).item.should.equal item1
      @team1.at(0).item.should.equal item2

    it "fails if the user or target has Sticky Hold", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Stick')]
        team2: [Factory('Gastrodon (east)', item: "Leftovers")]
      item1 = @team1.at(0).item
      item2 = @team2.at(0).item
      @battle.makeMove(@player1, 'Trick')
      @battle.makeMove(@player2, 'Recover')

      @team1.at(0).item.should.equal item1
      @team2.at(0).item.should.equal item2

    it "fails if the target has no item", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Stick')]
        team2: [Factory('Magikarp')]
      item1 = @team1.at(0).item
      item2 = @team2.at(0).item
      @battle.makeMove(@player1, 'Trick')
      @battle.makeMove(@player2, 'Splash')

      @team1.at(0).item.should.equal item1
      should.not.exist @team2.at(0).item

    it "fails if the user has no item", ->
      shared.create.call this,
        team1: [Factory('Alakazam')]
        team2: [Factory('Magikarp', item: 'Leftovers')]
      item1 = @team1.at(0).item
      item2 = @team2.at(0).item
      @battle.makeMove(@player1, 'Trick')
      @battle.makeMove(@player2, 'Splash')

      should.not.exist @team1.at(0).item
      @team2.at(0).item.should.equal item2

    it "fails if the user or target is holding a Mail"
    it "fails if the user or target is Giratina-O"
    it "fails if the target has a Substitute"
    it "fails if the user or target has Multitype with a plate item"
    it "fails if the user or target is Genesect with a Drive item"

  describe 'memento', ->
    shared.shouldDoNoDamage('Memento')

    it "faints the user", ->
      shared.create.call this,
        team1: [Factory('Latias')]
        team2: [Factory('Magikarp')]
      @battle.makeMove(@player1, 'Memento')
      @battle.makeMove(@player2, 'Splash')

      @team1.at(0).isFainted().should.be.true

    it "reduces the attack and special attack of the target by two stages", ->
      shared.create.call this,
        team1: [Factory('Latias')]
        team2: [Factory('Magikarp')]
      @battle.makeMove(@player1, 'Memento')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).stages.should.include attack: -2, specialAttack: -2

    it "doesn't reduce stats if target is protected, but still faints user"
    it "doesn't reduce stats if target has a substitute, but faints user"

  describe 'magnitude', ->
    it "has variable base power", ->
      shared.create.call this,
        team1: [Factory('Dugtrio')]
        team2: [Factory('Magikarp')]
      @battle.rng.randInt.restore()
      move = moves['magnitude']
      sinon.stub(@battle.rng, 'randInt', -> 50)
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 70

  describe 'pain split', ->
    it "doesn't make a pokemon's HP go over their max", ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Blissey')]
      @battle.makeMove(@player1, 'Pain Split')
      @battle.makeMove(@player1, 'Seismic Toss')

      @team1.at(0).currentHP.should.equal @team1.at(0).stat('hp')

    it "averages user and target current HP", ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Blissey')]
      @team1.at(0).currentHP = 2
      @battle.makeMove(@player1, 'Pain Split')
      @battle.makeMove(@player2, 'Seismic Toss')

      @team1.at(0).currentHP.should.equal Math.min(326, @team1.at(0).stat('hp'))
      @team2.at(0).currentHP.should.equal Math.min(326, @team2.at(0).stat('hp'))

  describe 'belly drum', ->
    shared.shouldDoNoDamage('Belly Drum')

    it "maximizes attack", ->
      shared.create.call this,
        team1: [Factory('Poliwrath')]
        team2: [Factory('Magikarp')]
      @team1.at(0).stages.attack = -6
      @battle.makeMove(@player1, 'Belly Drum')
      @battle.makeMove(@player2, 'Splash')

      @team1.at(0).stages.attack.should.equal 6

    it "cuts the pokemon's HP by half", ->
      shared.create.call this,
        team1: [Factory('Poliwrath')]
        team2: [Factory('Magikarp')]
      @battle.makeMove(@player1, 'Belly Drum')
      @battle.makeMove(@player2, 'Splash')

      hp = @team1.at(0).stat('hp')
      (hp - @team1.at(0).currentHP).should.equal Math.floor(hp / 2)

    it "fails if the pokemon's HP is less than half", ->
      shared.create.call this,
        team1: [Factory('Poliwrath')]
        team2: [Factory('Magikarp')]
      hp = @team1.at(0).currentHP = Math.floor(@team1.at(0).stat('hp') / 2) - 1
      @battle.makeMove(@player1, 'Belly Drum')
      @battle.makeMove(@player2, 'Splash')

      @team1.at(0).currentHP.should.equal hp
      @team1.at(0).stages.attack.should.equal 0

  describe 'acupressure', ->
    shared.shouldDoNoDamage('Acupressure')

    it "raises a random stat that can be raised", ->
      shared.create.call this,
        team1: [Factory('Shuckle')]
        team2: [Factory('Magikarp')]
      stages = _.clone(@team1.at(0).stages)
      @battle.makeMove(@player1, 'Acupressure')
      @battle.makeMove(@player2, 'Splash')

      @team1.at(0).stages.should.not.eql stages

    it "fails if the Pokemon has maximum stats", ->
      shared.create.call this,
        team1: [Factory('Shuckle')]
        team2: [Factory('Magikarp')]
      @team1.at(0).stages.attack = 6
      @team1.at(0).stages.defense = 6
      @team1.at(0).stages.specialAttack = 6
      @team1.at(0).stages.specialDefense = 6
      @team1.at(0).stages.accuracy = 6
      @team1.at(0).stages.evasion = 6
      mock = sinon.mock(@team2.at(0))
      mock.expects('boost').never()

      @battle.makeMove(@player1, 'Acupressure')
      @battle.makeMove(@player2, 'Splash')

      mock.verify()

  describe 'dragon-rage', ->
    it 'always does 40 damage', ->
      shared.create.call this,
        team1: [Factory('Dratini')]
        team2: [Factory('Magikarp')]
      move = moves['dragon-rage']
      move.calculateDamage(@battle, @team1.at(0), @team2.at(0)).should.equal 40

  describe 'explosion moves', ->
    it 'faints the user', ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Blissey')]
      @battle.makeMove(@player1, 'Explosion')
      @battle.makeMove(@player2, 'Seismic Toss')

      @team1.at(0).isFainted().should.be.true

    it 'faints the user even if enemy is immune', ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Gengar')]
      @battle.makeMove(@player1, 'Explosion')
      @battle.makeMove(@player2, 'Pain Split')

      @team1.at(0).isFainted().should.be.true

    it 'fails if an active Pokemon has Damp', ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Politoed', ability: 'Damp')]
      @battle.makeMove(@player1, 'Explosion')
      @battle.makeMove(@player2, 'Perish Song')

      @team1.at(0).isFainted().should.be.false

  describe 'endeavor', ->
    shared.shouldDoNoDamage('Endeavor')

    it "brings the target's hp down to the user's hp", ->
      shared.create.call this,
        team1: [Factory('Politoed')]
        team2: [Factory('Magikarp')]
      hp = 4
      @team1.at(0).currentHP = hp

      @battle.makeMove(@player1, 'Endeavor')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).currentHP.should.equal hp

    it "fails if the target's hp is less than the user's hp", ->
      shared.create.call this,
        team1: [Factory('Politoed')]
        team2: [Factory('Magikarp')]
      hp = 4
      @team2.at(0).currentHP = hp
      @battle.makeMove(@player1, 'Endeavor')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).currentHP.should.equal hp

    it "doesn't hit ghost pokemon", ->
      shared.create.call this,
        team1: [Factory('Politoed')]
        team2: [Factory('Gengar')]
      @team1.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Endeavor')
      @battle.makeMove(@player2, 'Dragon Dance')

      @team2.at(0).currentHP.should.equal @team2.at(0).stat('hp')

  describe 'a thief move', ->
    it "should steal the target's item", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Leftovers")]
      item2 = @team2.at(0).item
      @battle.makeMove(@player1, 'Thief')
      @battle.makeMove(@player2, 'Splash')

      @team1.at(0).item.should.equal item2
      should.not.exist @team2.at(0).item

    it "should not steal the target's item if user already has an item", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: "Stick")]
        team2: [Factory('Magikarp', item: "Leftovers")]
      item1 = @team1.at(0).item
      item2 = @team2.at(0).item
      @battle.makeMove(@player1, 'Thief')
      @battle.makeMove(@player2, 'Splash')

      @team1.at(0).item.should.equal item1
      @team2.at(0).item.should.equal item2

    it "should not steal the target's item if target has Sticky Hold", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Leftovers", ability: "Sticky Hold")]
      item2 = @team2.at(0).item
      @battle.makeMove(@player1, 'Thief')
      @battle.makeMove(@player2, 'Splash')

      should.not.exist @team1.at(0).item
      @team2.at(0).item.should.equal item2

    it "should not steal the target's item if target has Multitype", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Leftovers", ability: "Multitype")]
      item2 = @team2.at(0).item
      @battle.makeMove(@player1, 'Thief')
      @battle.makeMove(@player2, 'Splash')

      should.not.exist @team1.at(0).item
      @team2.at(0).item.should.equal item2

    # TODO: What about Genesect?
    it "should not steal the target's item if target is Giratina-O"

  describe 'crush grip', ->
    it 'has a base power of 1 minimum', ->
      shared.create.call(this)
      move = moves['crush-grip']
      @team2.at(0).currentHP = 1
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 1

    it 'has a base power of 121 maximum', ->
      shared.create.call(this)
      move = moves['crush-grip']
      @team2.at(0).currentHP = @team2.at(0).stat('hp')
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 121
