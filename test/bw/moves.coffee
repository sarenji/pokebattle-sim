sinon = require 'sinon'
{moves} = require('../../data/bw')
{Battle, Pokemon, Status, VolatileStatus, Weather} = require('../../').server
util = require '../../server/util'
{Factory} = require '../factory'
should = require 'should'
{_} = require 'underscore'
shared = require '../shared'

@test = ->
  describe 'splash', ->
    shared.shouldDoNoDamage('Splash')

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
      @nextStub.withArgs('secondary boost').returns(0)  # 100% chance
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
      @intStub.withArgs(sinon.match.any, sinon.match.any, 'psywave').returns(5)
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
      @intStub.withArgs(sinon.match.any, sinon.match.any, 'psywave').returns(15)
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
      @intStub.withArgs(sinon.match.any, sinon.match.any, 'psywave').returns(6.09)
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
      @team1.at(0).setStatus(Status.PARALYZE)
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

  describe 'disable', ->
    shared.shouldDoNoDamage('Disable')

    it 'gives the disabled attachment', ->
      shared.create.call this
      @battle.makeMove(@player1, 'Disable')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).hasAttachment('DisabledAttachment').should.be.true

    # remove this once 'disables the last move that hit successfully'
    # is implemented
    it 'prevents a move from being used', ->
      shared.create.call this
      numMoves = @team2.at(0).moves.length
      @battle.makeMove(@player1, 'Disable')
      @battle.makeMove(@player2, 'Splash')

      requestedMoves = @battle.requests[@player2.id].moves
      requestedMoves.length.should.equal (numMoves - 1)

    # Retest once we know disable's proper mechanics
    it 'wears off after a certain number of turns', ->
      shared.create.call this
      # minimum number of turns
      @intStub.withArgs(sinon.match.any, sinon.match.any, "disable").returns(4)

      @battle.makeMove(@player1, 'Disable')
      @battle.makeMove(@player2, 'Splash')

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).hasAttachment('DisabledAttachment').should.be.false

    it 'disables the last move that hit successfully'
    it 'causes a move to fail if the user moves first'

  describe 'hidden power', ->
    it 'has a max power of 70', ->
      ivs = {
        hp: 31, attack: 31, defense: 31, 
        specialAttack: 31, specialDefense: 31, speed: 31
      }
      shared.create.call this,
        team1: [Factory('Magikarp', ivs: ivs)]
        team2: [Factory('Magikarp')]
      move = moves['hidden-power']
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.eql 70

    it 'has a min power of 30', ->
      ivs = {
        hp: 0, attack: 0, defense: 0, 
        specialAttack: 0, specialDefense: 0, speed: 0
      }
      shared.create.call this,
        team1: [Factory('Magikarp', ivs: ivs)]
        team2: [Factory('Magikarp')]
      move = moves['hidden-power']
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.eql 30

    it 'is dark when all ivs are 31', ->
      ivs = {
        hp: 31, attack: 31, defense: 31, 
        specialAttack: 31, specialDefense: 31, speed: 31
      }
      shared.create.call this,
        team1: [Factory('Magikarp', ivs: ivs)]
        team2: [Factory('Magikarp')]
      move = moves['hidden-power']
      move.getType(@battle, @team1.at(0), @team2.at(0)).should.eql 'Dark'

    it 'is fighting when all ivs are 0', ->
      ivs = {
        hp: 0, attack: 0, defense: 0, 
        specialAttack: 0, specialDefense: 0, speed: 0
      }
      shared.create.call this,
        team1: [Factory('Magikarp', ivs: ivs)]
        team2: [Factory('Magikarp')]
      move = moves['hidden-power']
      move.getType(@battle, @team1.at(0), @team2.at(0)).should.eql 'Fighting'

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

    it "recovers 50% of the target's HP, rounded half up", ->
      shared.create.call this,
        team1: [Factory('Blissey')]
        team2: [Factory('Magikarp')]
      hp = @team1.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Softboiled')
      @battle.makeMove(@player2, 'Splash')

      recoverHP = Math.round(@team1.at(0).stat('hp') / 2)
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
      move = moves['magnitude']
      @intStub.withArgs(sinon.match.any, sinon.match.any, "magnitude").returns(50)
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
    it "should not steal the target's item if target holds Mail"

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

  describe 'hex', ->
    it 'doubles the base power if target is burned, poisoned, or paralyzed', ->
      shared.create.call(this)
      move = moves['hex']
      @team2.at(0).setStatus(Status.PARALYZE)
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 100

  describe 'heavy-slam', ->
    it 'has variable base power based on the difference in weight', ->
      shared.create.call(this)
      move = moves['heavy-slam']
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 40
      move.basePower(@battle, @team1.at(0), weight: -1000).should.equal 120

  describe 'a status cure move', ->
    it 'heals the entire team of status effects', ->
      shared.create.call this,
        team1: [Factory('Magikarp'), Factory('Magikarp'), Factory('Magikarp')]
      @team1.pokemon.map((pokemon) -> pokemon.setStatus(Status.PARALYZE))
      @battle.makeMove(@player1, 'Aromatherapy')
      @battle.makeMove(@player2, 'Splash')

      _.all(@team1.pokemon, (pokemon) -> !pokemon.hasStatus()).should.be.true

  describe 'copycat', ->
    beforeEach ->
      shared.create.call this,
        team1: [Factory('Magikarp', evs: {speed: 4})] # make faster than team2

    it 'copies the last move used', ->
      @battle.lastMove = moves['tackle']
      mock = sinon.mock(moves['tackle'])
      mock.expects('execute').once()
      @battle.makeMove(@player1, 'Copycat')
      @battle.makeMove(@player2, 'Splash')
      mock.restore()
      mock.verify()

    it 'fails if no last move was used', ->
      @battle.lastMove = null
      mock = sinon.mock(moves['copycat'])
      mock.expects('fail').once()
      @battle.makeMove(@player1, 'Copycat')
      @battle.makeMove(@player2, 'Splash')
      mock.restore()
      mock.verify()

    it 'fails if the last move was copycat', ->
      @battle.lastMove = moves['copycat']
      mock = sinon.mock(moves['copycat'])
      mock.expects('fail').once()
      @battle.makeMove(@player1, 'Copycat')
      @battle.makeMove(@player2, 'Splash')
      mock.restore()
      mock.verify()

  describe 'a move that targets a different stat', ->
    it "uses the correct stat", ->
      shared.create.call(this)
      move = moves['secret-sword']
      defStat = @team2.at(0).stat('defense')
      move.pickDefenseStat(@team1.at(0), @team2.at(0)).should.equal defStat

  describe 'foul play', ->
    it "uses the target's attack stat, not the user's", ->
      shared.create.call this,
        team1: [Factory('Celebi')]
      move = moves['foul-play']
      atkStat = @team2.at(0).stat('attack')
      move.pickAttackStat(@team1.at(0), @team2.at(0)).should.equal atkStat

  describe 'foul play', ->
    it "uses the target's attack stat, not the user's", ->
      shared.create.call this,
        team1: [Factory('Celebi')]
      move = moves['foul-play']
      atkStat = @team2.at(0).stat('attack')
      move.pickAttackStat(@team1.at(0), @team2.at(0)).should.equal atkStat

  describe 'teleport', ->
    it "always fails", ->
      shared.create.call(this)
      move = moves['teleport']
      mock = sinon.mock(move)
      mock.expects('fail').once()
      @battle.makeMove(@player1, 'Teleport')
      @battle.makeMove(@player2, 'Splash')
      mock.restore()
      mock.verify()

  describe 'Super Fang', ->
    it "deals half of the target's current HP", ->
      shared.create.call(this)
      hp = @team2.at(0).currentHP
      hp = @team2.at(0).currentHP = (hp - (1 - hp % 2))  # Always odd
      @battle.makeMove(@player1, 'Super Fang')
      @battle.makeMove(@player2, 'Splash')
      @team2.at(0).currentHP.should.equal Math.ceil(hp / 2)

    it "deals 1 damage minimum", ->
      shared.create.call(this)
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Super Fang')
      @battle.makeMove(@player2, 'Splash')
      @team2.at(0).currentHP.should.equal 0

  describe 'Avalanche', ->
    it "doubles base power if moving after target"
    it "has normal base power if moving before target"
    it "doesn't double base power if moving after target, then before target"

  describe "A weather-based recovery move", ->
    it "heals 50% HP in no weather, rounded half down", ->
      shared.create.call(this)
      @battle.setWeather(Weather.NONE)
      @team1.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Moonlight')
      @battle.makeMove(@player2, 'Splash')

      hp = util.roundHalfDown(@team1.at(0).stat('hp') / 2)
      @team1.at(0).currentHP.should.equal(1 + hp)

    it "heals 25% HP in bad weather, rounded half down", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SAND)
      @team1.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Moonlight')
      @battle.makeMove(@player2, 'Splash')

      hp = util.roundHalfDown(@team1.at(0).stat('hp') / 4)
      @team1.at(0).currentHP.should.equal(1 + hp)

    it "heals 66% HP in good weather, rounded half down", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SUN)
      @team1.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Moonlight')
      @battle.makeMove(@player2, 'Splash')

      hp = util.roundHalfDown(@team1.at(0).stat('hp') * 2 / 3)
      @team1.at(0).currentHP.should.equal(1 + hp)

  describe 'a flinching move', ->
    it "prevents the other person from executing their move", ->
      shared.create.call(this)

      mock = sinon.mock(moves['splash'])
      mock.expects('execute').never()

      @battle.makeMove(@player1, 'Fake Out')
      @battle.makeMove(@player2, 'Splash')

      mock.restore()
      mock.verify()

    it "removes the flinch attachment at the end of the turn", ->
      shared.create.call(this)

      @battle.makeMove(@player1, 'Fake Out')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).hasAttachment(VolatileStatus.FLINCH).should.be.false

  describe 'weather ball', ->
    it "is a 50 base power normal move in normal conditions", ->
      shared.create.call(this)
      @battle.setWeather(Weather.NONE)

      move = moves['weather-ball']
      move.getType(@battle, @team1.at(0), @team2.at(0)).should.equal 'Normal'
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 50

    it "is a 100 base power Water move in rain", ->
      shared.create.call(this)
      @battle.setWeather(Weather.RAIN)

      move = moves['weather-ball']
      move.getType(@battle, @team1.at(0), @team2.at(0)).should.equal 'Water'
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 100

    it "is a 100 base power Fire move in sun", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SUN)

      move = moves['weather-ball']
      move.getType(@battle, @team1.at(0), @team2.at(0)).should.equal 'Fire'
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 100

    it "is a 100 base power Ice move in hail", ->
      shared.create.call(this)
      @battle.setWeather(Weather.HAIL)

      move = moves['weather-ball']
      move.getType(@battle, @team1.at(0), @team2.at(0)).should.equal 'Ice'
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 100

    it "is a 100 base power Rock move in sandstorm", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SAND)

      move = moves['weather-ball']
      move.getType(@battle, @team1.at(0), @team2.at(0)).should.equal 'Rock'
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 100

