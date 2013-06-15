sinon = require 'sinon'
{moves} = require('../../data/bw')
{Attachment, Battle, Pokemon, Status, VolatileStatus, Weather} = require('../../').server
util = require '../../server/util'
{finalModifier} = require '../../server/modifiers'
{Factory} = require '../factory'
should = require 'should'
{_} = require 'underscore'
shared = require '../shared'

@test = ->
  describe 'splash', ->
    shared.shouldDoNoDamage('Splash')

  describe 'jump kick attacks', ->
    it 'has 50% recoil if it misses', ->
      shared.create.call(this)
      move = moves['hi-jump-kick']
      shared.biasRNG.call(this, "randInt", 'miss', 100)
      originalHP = @team1.at(0).currentHP
      @battle.performMove(@id1, move)
      damage = move.calculateDamage(@battle, @team1.first(), @team2.first())
      (originalHP - @team1.at(0).currentHP).should.equal Math.floor(damage / 2)

  describe 'drain attacks', ->
    it 'recovers a percentage of the damage dealt, rounded down', ->
      shared.create.call this,
        team1: [Factory('Conkeldurr')]
        team2: [Factory('Hitmonchan')]
      startHP = 1
      @team1.at(0).currentHP = startHP
      hp = @team2.at(0).currentHP
      @battle.performMove(@id1, moves['drain-punch'])
      damage = (hp - @team2.at(0).currentHP)
      (@team1.at(0).currentHP - startHP).should.equal Math.floor(damage / 2)

    it 'cannot recover to over 100% HP', ->
      shared.create.call this,
        team1: [Factory('Conkeldurr')]
        team2: [Factory('Hitmonchan')]
      hp = @team1.at(0).currentHP = @team1.at(0).stat('hp')
      @battle.performMove(@id1, moves['drain-punch'])
      (@team1.at(0).currentHP - hp).should.equal 0

  describe 'weight-based attacks', ->
    it 'has 80 base power if the pokemon is 50.2kg', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Hitmonchan')]
      hp = @team2.at(0).currentHP
      @battle.performMove(@id1, moves['grass-knot'])
      (hp - @team2.at(0).currentHP).should.equal 94

    it 'has 120 base power if the pokemon is >200kg', ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      hp = @team2.at(0).currentHP
      @battle.performMove(@id1, moves['grass-knot'])
      (hp - @team2.at(0).currentHP).should.equal 153

  describe 'a pokemon using a primary boosting move', ->
    it "doesn't do damage if base power is 0", ->
      shared.create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Hitmonchan')]
      @battle.performMove(@id1, moves['dragon-dance'])
      @team2.at(0).currentHP.should.equal @team2.at(0).stat('hp')

    it "boosts the pokemon's stats", ->
      shared.create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Hitmonchan')]
      attack = @team1.at(0).stat('attack')
      speed  = @team1.at(0).stat('speed')
      @battle.performMove(@id1, moves['dragon-dance'])
      @team1.at(0).stages.should.include attack: 1, speed: 1

    it "affects type-immune pokemon", ->
      shared.create.call this,
        team1: [Factory('Audino')]
        team2: [Factory('Gengar')]
      @battle.performMove(@id1, moves['growl'])
      @team2.at(0).stages.attack.should.equal -1

    it "has the boosts removed on switch"

  describe 'a pokemon using a damaging move that also boosts stats on hit', ->
    it "deals damage and boosts stats", ->
      shared.create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      hp = @team2.at(0).currentHP
      @battle.performMove(@id1, moves['leaf-storm'])
      @team1.at(0).stages.specialAttack.should.equal -2
      (hp - @team2.at(0).currentHP).should.equal 178

  describe 'a pokemon using a move with a secondary boosting effect', ->
    it "has a chance to activate", ->
      shared.create.call this,
        team1: [Factory('Mew')]
        team2: [Factory('Hitmonchan')]
      shared.biasRNG.call(this, "next", 'secondary boost', 0)  # 100% chance
      attack = @team1.at(0).stat('attack')
      speed  = @team1.at(0).stat('speed')
      @battle.performMove(@id1, moves['ancientpower'])
      @team1.at(0).stages.should.include {
        attack: 1, defense: 1, speed: 1, specialAttack: 1, specialDefense: 1
      }

  describe 'a pokemon using Acrobatics', ->
    it 'gets double the base power without an item', ->
      shared.create.call this,
        team1: [Factory('Gliscor')]
        team2: [Factory('Regirock')]
      hp = @team2.at(0).currentHP
      @battle.performMove(@id1, moves['acrobatics'])
      damage = (hp - @team2.at(0).currentHP)
      damage.should.equal 36

    it 'has normal base power with an item', ->
      shared.create.call this,
        team1: [Factory('Gliscor', item: 'Leftovers')]
        team2: [Factory('Regirock')]
      hp = @team2.at(0).currentHP
      @battle.performMove(@id1, moves['acrobatics'])
      damage = (hp - @team2.at(0).currentHP)
      damage.should.equal 18

  testRecoilMove = (moveName, recoil) ->
    describe "a pokemon using #{moveName}", ->
      it 'receives a percentage of the damage rounded half up', ->
        shared.create.call this,
          team1: [Factory('Blaziken')]
          team2: [Factory('Magikarp')]
        startHP = @team1.first().currentHP
        hp = @team2.first().currentHP

        move = @battle.getMove(moveName)
        @battle.performMove(@id1, move)

        damage = (hp - @team2.first().currentHP)
        (startHP - @team1.first().currentHP).should.equal Math.round(damage * recoil)

      it 'receives a minimum of 1 HP of recoil', ->
        shared.create.call this,
          team1: [Factory('Blaziken')]
          team2: [Factory('Magikarp')]
        startHP = @team1.first().currentHP
        hp = @team2.first().currentHP

        move = moves[moveName.toLowerCase().replace(/\s+/g, '-')]
        stub = sinon.stub(move, 'calculateDamage', -> .6)

        move = @battle.getMove(moveName)
        @battle.performMove(@id1, move)

        stub.restore()

        damage = (hp - @team2.first().currentHP)
        (startHP - @team1.first().currentHP).should.equal 1

  testRecoilMove("Brave Bird", 1/3)
  testRecoilMove("Double-Edge", 1/3)
  testRecoilMove("Flare Blitz", 1/3)
  testRecoilMove("Head Charge", .25)
  testRecoilMove("Head Smash", .5)
  testRecoilMove("Submission", .25)
  testRecoilMove("Take Down", .25)
  testRecoilMove("Volt Tackle", 1/3)
  testRecoilMove("Wild Charge", .25)
  testRecoilMove("Wood Hammer", 1/3)

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
      @battle.performMove(@id1, moves['haze'])
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
      @battle.performMove(@id1, moves['seismic-toss'])
      (hp - @team2.at(0).currentHP).should.equal 100

  describe 'Psywave', ->
    it 'does user.level/2 damage minimum', ->
      shared.create.call this,
        team1: [Factory('Weezing')]
        team2: [Factory('Mew')]
      shared.biasRNG.call(this, "randInt", 'psywave', 5)
      hp = @team2.at(0).currentHP
      @battle.performMove(@id1, moves['psywave'])
      (hp - @team2.at(0).currentHP).should.equal 50

    it 'does user.level * 1.5 damage maximum', ->
      shared.create.call this,
        team1: [Factory('Weezing')]
        team2: [Factory('Mew')]
      move = moves['psywave']
      shared.biasRNG.call(this, "randInt", 'psywave', 15)
      hp = @team2.at(0).currentHP
      @battle.performMove(@id1, moves['psywave'])
      (hp - @team2.at(0).currentHP).should.equal 150

    it 'rounds down to the nearest .1 multiplier', ->
      shared.create.call this,
        team1: [Factory('Weezing')]
        team2: [Factory('Mew')]
      move = moves['psywave']
      shared.biasRNG.call(this, "randInt", 'psywave', 6.09)
      hp = @team2.at(0).currentHP
      @battle.performMove(@id1, moves['psywave'])
      (hp - @team2.at(0).currentHP).should.equal 60

  describe 'facade', ->
    it 'doubles the base power if burned, poisoned, or paralyzed', ->
      shared.create.call this,
        team1: [Factory('Zangoose')]
        team2: [Factory('Magikarp')]
      hp = @team2.first().currentHP
      @team1.first().setStatus(Status.PARALYZE)
      move = moves['facade']
      basePower = move.basePower(@battle, @team1.first(), @team2.first())
      basePower.should.equal(2 * move.power)

  describe 'reversal and flail', ->
    it 'have 200 base power at 1 hp', ->
      shared.create.call this,
        team1: [Factory('Zangoose')]
        team2: [Factory('Magikarp')]
      @team1.at(0).currentHP = 1
      move = moves['flail']
      basePower = move.basePower(@battle, @team1.first(), @team2.first())
      basePower.should.equal 200

    it 'have 40 base power at 50% hp', ->
      shared.create.call this,
        team1: [Factory('Zangoose')]
        team2: [Factory('Magikarp')]
      @team1.at(0).currentHP = Math.floor(@team1.at(0).stat('hp') / 2)
      move = moves['flail']
      basePower = move.basePower(@battle, @team1.first(), @team2.first())
      basePower.should.equal 40

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
      @controller.makeMove(@player1, 'Disable')
      @controller.makeMove(@player2, 'Splash')

      @team2.at(0).hasAttachment(Attachment.Disable).should.be.true

    # remove this once 'disables the last move that hit successfully'
    # is implemented
    it 'prevents a move from being used', ->
      shared.create.call this
      numMoves = @team2.at(0).moves.length
      @controller.makeMove(@player1, 'Disable')
      @controller.makeMove(@player2, 'Splash')

      requestedMoves = @battle.requests[@player2.id].moves
      requestedMoves.length.should.equal (numMoves - 1)

    # Retest once we know disable's proper mechanics
    it 'wears off after a certain number of turns', ->
      shared.create.call this
      # minimum number of turns
      shared.biasRNG.call(this, "randInt", 'disable', 4)

      @controller.makeMove(@player1, 'Disable')
      @controller.makeMove(@player2, 'Splash')

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @controller.makeMove(@player1, 'Splash')
      @controller.makeMove(@player2, 'Splash')

      @team2.at(0).hasAttachment(Attachment.Disable).should.be.false

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
      @controller.makeMove(@player1, 'Yawn')
      @controller.makeMove(@player2, 'Splash')

      @team2.at(0).hasAttachment(Attachment.Yawn).should.be.true

    it 'puts the opponent to sleep at the end of the second turn', ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Magikarp')]
      @controller.makeMove(@player1, 'Yawn')
      @controller.makeMove(@player2, 'Splash')

      @controller.makeMove(@player1, 'Yawn')
      @controller.makeMove(@player2, 'Splash')

      @team2.at(0).hasStatus(Status.SLEEP).should.be.true
      @battle.turn.should.equal 3

    it 'does not put the opponent to sleep at the end of the first turn', ->
      shared.create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Magikarp')]
      @controller.makeMove(@player1, 'Yawn')
      @controller.makeMove(@player2, 'Splash')

      @team2.at(0).hasStatus(Status.SLEEP).should.be.false
      @battle.turn.should.equal 2

    it "fails if the target is already yawning", ->
      shared.create.call(this)
      mock = sinon.mock(moves['yawn'])
      mock.expects('fail').once()

      @battle.performMove(@id1, moves['yawn'])
      @battle.performMove(@id1, moves['yawn'])

      mock.restore()
      mock.verify()

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
      @team2.first().currentHP = Math.floor(@team2.first().stat('hp') / 2)
      @controller.makeMove(@player1, 'Sheer Cold')
      @controller.makeMove(@player2, 'Splash')

      move = moves['sheer-cold']
      damage = move.calculateDamage(@battle, @team1.first(), @team2.first())
      damage.should.equal @team2.first().stat('hp')

  describe 'a recovery move', ->
    shared.shouldDoNoDamage('Recover')

    it "recovers 50% of the target's HP, rounded half up", ->
      shared.create.call(this)
      hp = @team1.at(0).currentHP = 1
      @controller.makeMove(@player1, 'Softboiled')
      @controller.makeMove(@player2, 'Splash')

      recoverHP = Math.round(@team1.at(0).stat('hp') / 2)
      (@team1.at(0).currentHP - hp).should.equal recoverHP

    it "fails if the user's HP is full", ->
      shared.create.call(this)
      mock = sinon.mock(moves['softboiled'])
      mock.expects('fail').once()

      @controller.makeMove(@player1, 'Softboiled')
      @controller.makeMove(@player2, 'Splash')

      mock.restore()
      mock.verify()

  describe 'knock off', ->
    it "deals damage", ->
      shared.create.call this,
        team1: [Factory('Drapion')]
        team2: [Factory('Magikarp', item: "Leftovers")]
      @controller.makeMove(@player1, 'Knock Off')
      @controller.makeMove(@player2, 'Splash')

      @team2.at(0).currentHP.should.be.lessThan @team2.at(0).stat('hp')

    it "removes the target's item", ->
      shared.create.call this,
        team1: [Factory('Drapion')]
        team2: [Factory('Magikarp', item: "Leftovers")]
      @controller.makeMove(@player1, 'Knock Off')
      @controller.makeMove(@player2, 'Splash')

      should.not.exist @team2.at(0).item

  describe 'trick and switcheroo', ->
    shared.shouldDoNoDamage('Trick')

    it "isn't affected by type-immunities", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Stick')]
        team2: [Factory('Drapion', item: "Leftovers")]
      item1 = @team1.at(0).item
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Trick')
      @controller.makeMove(@player2, 'Swords Dance')

      @team2.at(0).item.should.equal item1
      @team1.at(0).item.should.equal item2

    it "swaps the target and user's item", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Stick')]
        team2: [Factory('Magikarp', item: "Leftovers")]
      item1 = @team1.at(0).item
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Trick')
      @controller.makeMove(@player2, 'Splash')

      @team2.at(0).item.should.equal item1
      @team1.at(0).item.should.equal item2

    it "fails if the user or target has Sticky Hold", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Stick')]
        team2: [Factory('Gastrodon (east)', item: "Leftovers")]
      item1 = @team1.at(0).item
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Trick')
      @controller.makeMove(@player2, 'Recover')

      @team1.at(0).item.should.equal item1
      @team2.at(0).item.should.equal item2

    it "fails if the target has no item", ->
      shared.create.call this,
        team1: [Factory('Alakazam', item: 'Stick')]
        team2: [Factory('Magikarp')]
      item1 = @team1.at(0).item
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Trick')
      @controller.makeMove(@player2, 'Splash')

      @team1.at(0).item.should.equal item1
      should.not.exist @team2.at(0).item

    it "fails if the user has no item", ->
      shared.create.call this,
        team1: [Factory('Alakazam')]
        team2: [Factory('Magikarp', item: 'Leftovers')]
      item1 = @team1.at(0).item
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Trick')
      @controller.makeMove(@player2, 'Splash')

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
      @controller.makeMove(@player1, 'Memento')
      @controller.makeMove(@player2, 'Splash')

      @team1.at(0).isFainted().should.be.true

    it "reduces the attack and special attack of the target by two stages", ->
      shared.create.call this,
        team1: [Factory('Latias')]
        team2: [Factory('Magikarp')]
      @controller.makeMove(@player1, 'Memento')
      @controller.makeMove(@player2, 'Splash')

      @team2.at(0).stages.should.include attack: -2, specialAttack: -2

    it "doesn't reduce stats if target is protected, but still faints user"
    it "doesn't reduce stats if target has a substitute, but faints user"

  describe 'magnitude', ->
    it "has variable base power", ->
      shared.create.call this,
        team1: [Factory('Dugtrio')]
        team2: [Factory('Magikarp')]
      move = moves['magnitude']
      shared.biasRNG.call(this, "randInt", 'magnitude', 50)
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 70

  describe 'pain split', ->
    it "doesn't make a pokemon's HP go over their max", ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Blissey')]
      @controller.makeMove(@player1, 'Pain Split')
      @controller.makeMove(@player1, 'Seismic Toss')

      @team1.at(0).currentHP.should.equal @team1.at(0).stat('hp')

    it "averages user and target current HP", ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Blissey')]
      @team1.at(0).currentHP = 2
      @controller.makeMove(@player1, 'Pain Split')
      @controller.makeMove(@player2, 'Seismic Toss')

      @team1.at(0).currentHP.should.equal Math.min(326, @team1.at(0).stat('hp'))
      @team2.at(0).currentHP.should.equal Math.min(326, @team2.at(0).stat('hp'))

  describe 'belly drum', ->
    shared.shouldDoNoDamage('Belly Drum')

    it "maximizes attack", ->
      shared.create.call this,
        team1: [Factory('Poliwrath')]
        team2: [Factory('Magikarp')]
      @team1.at(0).stages.attack = -6
      @controller.makeMove(@player1, 'Belly Drum')
      @controller.makeMove(@player2, 'Splash')

      @team1.at(0).stages.attack.should.equal 6

    it "cuts the pokemon's HP by half", ->
      shared.create.call this,
        team1: [Factory('Poliwrath')]
        team2: [Factory('Magikarp')]
      @controller.makeMove(@player1, 'Belly Drum')
      @controller.makeMove(@player2, 'Splash')

      hp = @team1.at(0).stat('hp')
      (hp - @team1.at(0).currentHP).should.equal Math.floor(hp / 2)

    it "fails if the pokemon's HP is less than half", ->
      shared.create.call this,
        team1: [Factory('Poliwrath')]
        team2: [Factory('Magikarp')]
      hp = @team1.at(0).currentHP = Math.floor(@team1.at(0).stat('hp') / 2) - 1
      @controller.makeMove(@player1, 'Belly Drum')
      @controller.makeMove(@player2, 'Splash')

      @team1.at(0).currentHP.should.equal hp
      @team1.at(0).stages.attack.should.equal 0

  describe 'acupressure', ->
    shared.shouldDoNoDamage('Acupressure')

    it "raises a random stat that can be raised", ->
      shared.create.call this,
        team1: [Factory('Shuckle')]
        team2: [Factory('Magikarp')]
      stages = _.clone(@team1.at(0).stages)
      @controller.makeMove(@player1, 'Acupressure')
      @controller.makeMove(@player2, 'Splash')

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

      @controller.makeMove(@player1, 'Acupressure')
      @controller.makeMove(@player2, 'Splash')

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
      @controller.makeMove(@player1, 'Explosion')
      @controller.makeMove(@player2, 'Seismic Toss')

      @team1.at(0).isFainted().should.be.true

    it 'faints the user even if enemy is immune', ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Gengar')]
      @controller.makeMove(@player1, 'Explosion')
      @controller.makeMove(@player2, 'Splash')

      @team1.at(0).isFainted().should.be.true

    it 'fails if an active Pokemon has Damp', ->
      shared.create.call this,
        team1: [Factory('Gengar')]
        team2: [Factory('Politoed', ability: 'Damp')]
      @controller.makeMove(@player1, 'Explosion')
      @controller.makeMove(@player2, 'Perish Song')

      @team1.at(0).isFainted().should.be.false

  describe 'endeavor', ->
    it "brings the target's hp down to the user's hp", ->
      shared.create.call(this)
      hp = 4
      @team1.first().currentHP = hp
      @battle.performMove(@id1, @battle.getMove('Endeavor'))
      @team2.first().currentHP.should.equal hp

    it "fails if the target's hp is less than the user's hp", ->
      shared.create.call(this)
      move = @battle.getMove('Endeavor')
      mock = sinon.mock(move)
      mock.expects('fail').once()
      @team2.first().currentHP = hp = 4

      @battle.performMove(@id1, move)
      mock.restore()
      mock.verify()

    it "doesn't hit ghost pokemon", ->
      shared.create.call this,
        team1: [Factory('Politoed')]
        team2: [Factory('Gengar')]
      @team1.first().currentHP = 1
      @battle.performMove(@id1, @battle.getMove('Endeavor'))
      @team2.first().currentHP.should.equal @team2.at(0).stat('hp')

  describe 'a thief move', ->
    it "should steal the target's item", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Leftovers")]
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Thief')
      @controller.makeMove(@player2, 'Splash')

      @team1.at(0).item.should.equal item2
      should.not.exist @team2.at(0).item

    it "should not steal the target's item if it has none", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp')]
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Thief')
      @controller.makeMove(@player2, 'Splash')

      should.not.exist @team1.at(0).item
      should.not.exist @team2.at(0).item

    it "should not steal the target's item if user already has an item", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: "Stick")]
        team2: [Factory('Magikarp', item: "Leftovers")]
      item1 = @team1.at(0).item
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Thief')
      @controller.makeMove(@player2, 'Splash')

      @team1.at(0).item.should.equal item1
      @team2.at(0).item.should.equal item2

    it "should not steal the target's item if target has Sticky Hold", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Leftovers", ability: "Sticky Hold")]
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Thief')
      @controller.makeMove(@player2, 'Splash')

      should.not.exist @team1.at(0).item
      @team2.at(0).item.should.equal item2

    it "should not steal the target's item if target has Multitype", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Leftovers", ability: "Multitype")]
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Thief')
      @controller.makeMove(@player2, 'Splash')

      should.not.exist @team1.at(0).item
      @team2.at(0).item.should.equal item2

    it "should not steal the target's item if the target has no item", ->
      shared.create.call(this)
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Thief')
      @controller.makeMove(@player2, 'Splash')

      @team1.first().hasItem().should.be.false
      @team2.first().hasItem().should.be.false

    # TODO: What about Genesect?
    it "should not steal the target's item if target is Giratina-O", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Giratina (origin)', item: "Griseous Orb")]
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Thief')
      @controller.makeMove(@player2, 'Splash')

      should.not.exist @team1.at(0).item
      @team2.at(0).item.should.equal item2

    it "should not steal the target's item if target holds Mail", ->
      shared.create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp', item: "Air Mail")]
      item2 = @team2.at(0).item
      @controller.makeMove(@player1, 'Thief')
      @controller.makeMove(@player2, 'Splash')

      should.not.exist @team1.at(0).item
      @team2.at(0).item.should.equal item2

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

  describe 'heavy slam and heat crash', ->
    it 'has variable base power based on the difference in weight', ->
      shared.create.call(this)
      move = moves['heavy-slam']
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 40
      move.basePower(@battle, @team1.at(0), calculateWeight: -> -1000).should.equal 120

  describe 'a status cure move', ->
    it 'heals the entire team of status effects', ->
      shared.create.call this,
        team1: [Factory('Magikarp'), Factory('Magikarp'), Factory('Magikarp')]
      @team1.pokemon.map((pokemon) -> pokemon.setStatus(Status.PARALYZE))
      @battle.performMove(@id1, moves['aromatherapy'])

      _.all(@team1.pokemon, (pokemon) -> !pokemon.hasStatus()).should.be.true

  describe 'copycat', ->
    beforeEach ->
      shared.create.call this,
        team1: [Factory('Magikarp', evs: {speed: 4})] # make faster than team2

    it 'copies the last move used', ->
      @battle.lastMove = moves['tackle']
      mock = sinon.mock(moves['tackle'])
      mock.expects('execute').once()
      @battle.performMove(@id1, moves['copycat'])
      mock.restore()
      mock.verify()

    it 'fails if no last move was used', ->
      @battle.lastMove = null
      mock = sinon.mock(moves['copycat'])
      mock.expects('fail').once()
      @battle.performMove(@id1, moves['copycat'])
      mock.restore()
      mock.verify()

    it 'fails if the last move was copycat', ->
      @battle.lastMove = moves['copycat']
      mock = sinon.mock(moves['copycat'])
      mock.expects('fail').once()
      @battle.performMove(@id1, moves['copycat'])
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
      @controller.makeMove(@player1, 'Teleport')
      @controller.makeMove(@player2, 'Splash')
      mock.restore()
      mock.verify()

  describe 'Super Fang', ->
    it "deals half of the target's current HP", ->
      shared.create.call(this)
      hp = @team2.at(0).currentHP
      hp = @team2.at(0).currentHP = (hp - (1 - hp % 2))  # Always odd
      @controller.makeMove(@player1, 'Super Fang')
      @controller.makeMove(@player2, 'Splash')
      @team2.at(0).currentHP.should.equal Math.ceil(hp / 2)

    it "deals 1 damage minimum", ->
      shared.create.call(this)
      @team2.at(0).currentHP = 1
      @controller.makeMove(@player1, 'Super Fang')
      @controller.makeMove(@player2, 'Splash')
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
      @controller.makeMove(@player1, 'Moonlight')
      @controller.makeMove(@player2, 'Splash')

      hp = util.roundHalfDown(@team1.at(0).stat('hp') / 2)
      @team1.at(0).currentHP.should.equal(1 + hp)

    it "heals 25% HP in bad weather, rounded half down", ->
      shared.create.call(this, team1: [Factory("Shuckle")])
      @battle.setWeather(Weather.SAND)
      @team1.at(0).currentHP = 1
      @controller.makeMove(@player1, 'Moonlight')
      @controller.makeMove(@player2, 'Splash')

      hp = util.roundHalfDown(@team1.at(0).stat('hp') / 4)
      @team1.at(0).currentHP.should.equal(1 + hp)

    it "heals 66% HP in good weather, rounded half down", ->
      shared.create.call(this)
      @battle.setWeather(Weather.SUN)
      @team1.at(0).currentHP = 1
      @controller.makeMove(@player1, 'Moonlight')
      @controller.makeMove(@player2, 'Splash')

      hp = util.roundHalfDown(@team1.at(0).stat('hp') * 2 / 3)
      @team1.at(0).currentHP.should.equal(1 + hp)

  describe 'a flinching move', ->
    it "prevents the other person from executing their move", ->
      shared.create.call(this)

      mock = sinon.mock(moves['splash'])
      mock.expects('execute').never()

      @controller.makeMove(@player1, 'Fake Out')
      @controller.makeMove(@player2, 'Splash')

      mock.restore()
      mock.verify()

    it "removes the flinch attachment at the end of the turn", ->
      shared.create.call(this)

      @controller.makeMove(@player1, 'Fake Out')
      @controller.makeMove(@player2, 'Splash')

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

  describe 'autotomize', ->
    it 'changes your weight on success', ->
      shared.create.call(this)
      weight = @team1.at(0).calculateWeight()
      @controller.makeMove(@player1, 'autotomize')
      @controller.makeMove(@player2, 'splash')

      weight.should.not.equal @team1.at(0).calculateWeight()

    it 'cannot go below .1kg', ->
      # Magikarp weighs 100kg.
      shared.create.call this, team1: [ Factory('Magikarp')]
      @controller.makeMove(@player1, 'autotomize')
      @controller.makeMove(@player2, 'splash')

      @team1.at(0).calculateWeight().should.not.be.lessThan .1

    it 'stacks weight changes', ->
      it 'cannot go below .1kg', ->
      # Magikarp weighs 1355kg.
      shared.create.call this, team1: [ Factory('Abomasnow')]

      @controller.makeMove(@player1, 'autotomize')
      @controller.makeMove(@player2, 'splash')
      @controller.makeMove(@player1, 'autotomize')
      @controller.makeMove(@player2, 'splash')

      @team1.at(0).calculateWeight().should.equal 1155

  describe 'heart swap', ->
    shared.shouldDoNoDamage('Heart Swap')

    it 'swaps user and target boosts', ->
      shared.create.call(this)
      @team1.at(0).stages.attack = 2
      @team2.at(0).stages.speed = -2

      @controller.makeMove(@player1, 'heart-swap')
      @controller.makeMove(@player2, 'splash')

      @team1.at(0).stages.should.include speed: -2
      @team2.at(0).stages.should.include attack: 2

  describe 'nightmare', ->
    shared.shouldDoNoDamage('Nightmare')

    it 'fails if the pokemon is awake', ->
      shared.create.call(this)

      mock = sinon.mock(moves['nightmare'])
      mock.expects('fail').once()

      @controller.makeMove(@player1, 'nightmare')
      @controller.makeMove(@player2, 'splash')

      mock.restore()
      mock.verify()

    it "cuts the target's HP by 25% each turn", ->
      shared.create.call(this)
      @team2.at(0).setStatus(Status.SLEEP)

      hp = @team2.at(0).currentHP
      quarter = Math.floor(hp / 4)

      @controller.makeMove(@player1, 'nightmare')
      @controller.makeMove(@player2, 'splash')

      @team2.at(0).currentHP.should.equal(hp - quarter)

      @controller.makeMove(@player1, 'splash')
      @controller.makeMove(@player2, 'splash')

      @team2.at(0).currentHP.should.equal(hp - 2*quarter)

    it "stops the nightmare if the target wakes up", ->
      shared.create.call(this)
      @team2.at(0).setStatus(Status.SLEEP)

      @controller.makeMove(@player1, 'nightmare')
      @controller.makeMove(@player2, 'splash')

      @team2.at(0).cureStatus()

      @controller.makeMove(@player1, 'splash')
      @controller.makeMove(@player2, 'splash')

      @team2.at(0).hasAttachment(Attachment.Nightmare).should.be.false

  describe 'incinerate', ->
    it 'destroys the berry of the target', ->
      shared.create.call this,
        team2: [ Factory('Magikarp', item: 'Bluk Berry') ]

      @controller.makeMove(@player1, 'incinerate')
      @controller.makeMove(@player2, 'splash')

      should.not.exist @team2.at(0).item

    it 'does not destroy non-berries', ->
      shared.create.call this,
        team2: [ Factory('Magikarp', item: 'Leftovers') ]

      @controller.makeMove(@player1, 'incinerate')
      @controller.makeMove(@player2, 'splash')

      should.exist @team2.at(0).item

  describe 'judgment', ->
    it 'is normal type by default', ->
      shared.create.call(this)
      move = moves['judgment']
      move.getType(@battle, @team1.at(0), @team2.at(0)).should.equal 'Normal'

    it 'changes type depending on the Plate held by the user', ->
      shared.create.call this,
        team1: [ Factory('Magikarp', item: 'Earth Plate') ]
      move = moves['judgment']
      move.getType(@battle, @team1.at(0), @team2.at(0)).should.equal 'Ground'

  describe 'taunt', ->
    it 'prevents the target from using a non-attacking move that turn', ->
      shared.create.call(this, team1: [ Factory('Magikarp', evs: {speed: 4}) ])
      move = moves['calm-mind']
      mock = sinon.mock(move)
      mock.expects('execute').never()

      @controller.makeMove(@player1, 'taunt')
      @controller.makeMove(@player2, 'calm-mind')

      mock.restore()
      mock.verify()

    it 'lasts three turns', ->
      shared.create.call(this, team1: [ Factory('Magikarp', evs: {speed: 4}) ])

      @controller.makeMove(@player1, 'taunt')
      @controller.makeMove(@player2, 'calm-mind')

      @controller.makeMove(@player1, 'splash')
      @controller.makeMove(@player2, 'tackle')

      @controller.makeMove(@player1, 'splash')
      @controller.makeMove(@player2, 'tackle')

      @team2.at(0).hasAttachment(Attachment.Taunt).should.be.false

    it 'prevents the target from selecting that move the next turn', ->
      shared.create.call(this)

      @controller.makeMove(@player1, 'taunt')
      @controller.makeMove(@player2, 'calm-mind')

      requestedMoves = @battle.requests[@player2.id].moves
      requestedMoves.should.not.include 'Splash'

    it "fails if the target is already under taunt", ->
      shared.create.call(this)
      mock = sinon.mock(moves['taunt'])
      mock.expects('fail').once()

      @battle.performMove(@id1, moves['taunt'])
      @battle.performMove(@id1, moves['taunt'])

      mock.restore()
      mock.verify()

  describe 'u-turn', ->
    it 'forces the owner to switch', ->
      shared.create.call(this)
      @controller.makeMove(@player1, 'u-turn')
      @controller.makeMove(@player2, 'splash')

      @battle.requests.should.have.property @player1.id
      @battle.turn.should.equal 1

  describe 'venoshock', ->
    it 'doubles the base power if target is poisoned', ->
      shared.create.call(this)
      move = moves['venoshock']
      @team2.at(0).setStatus(Status.POISON)
      basePower = move.basePower(@battle, @team1.first(), @team2.first())
      basePower.should.equal(2 * move.power)

  describe 'Wish', ->
    it "restores half of the user's total hit points the next end of turn", ->
      shared.create.call(this)
      hp = @team1.first().currentHP
      @team1.first().currentHP = 1
      @controller.makeMove(@player1, 'wish')
      @controller.makeMove(@player2, 'splash')

      @team1.first().currentHP.should.equal 1

      @controller.makeMove(@player1, 'splash')
      @controller.makeMove(@player2, 'splash')

      @team1.first().currentHP.should.equal(Math.round(hp / 2) + 1)

    it "restores the same total amount of HP to an ally", ->
      shared.create.call(this, team1: [Factory("Magikarp"), Factory("Celebi")])
      hp = @team1.first().currentHP
      @controller.makeMove(@player1, 'wish')
      @controller.makeMove(@player2, 'splash')

      @team1.at(1).currentHP = 1
      @controller.makeSwitch(@player1, 1)
      @controller.makeMove(@player2, 'splash')

      @team1.first().currentHP.should.equal(Math.round(hp / 2) + 1)

    it "fails if the pokemon faints", ->
      shared.create.call(this, team1: [Factory("Magikarp"), Factory("Celebi")])
      @controller.makeMove(@player1, 'wish')
      @controller.makeMove(@player2, 'splash')

      @team1.at(0).currentHP = 1
      @controller.makeMove(@player1, 'splash')
      @controller.makeMove(@player2, 'tackle')

      @team1.hasAttachment(Attachment.Wish).should.be.false

    it "fails if the user already used Wish", ->
      shared.create.call(this)
      mock = sinon.mock(moves['wish'])
      mock.expects('fail').once()

      @battle.performMove(@id1, moves['wish'])
      @battle.performMove(@id1, moves['wish'])

      mock.restore()
      mock.verify()

  describe "counter", ->
    it "returns double the damage if attacked by a physical move", ->
      shared.create.call(this)
      @controller.makeMove(@player1, 'counter')
      @controller.makeMove(@player2, 'tackle')

      dhp1 = @team1.at(0).stat('hp') - @team1.at(0).currentHP
      dhp2 = @team2.at(0).stat('hp') - @team2.at(0).currentHP
      dhp2.should.equal 2*dhp1

    it "fails if attacked by a special move", ->
      shared.create.call(this)
      mock = sinon.mock(moves['counter'])
      mock.expects('fail').once()
      @controller.makeMove(@player1, 'counter')
      @controller.makeMove(@player2, 'thundershock')

      mock.restore()
      mock.verify()

    it "fails if not hit by an attack this turn", ->
      shared.create.call(this)
      mock = sinon.mock(moves['counter'])
      mock.expects('fail').once()
      @controller.makeMove(@player1, 'splash')
      @controller.makeMove(@player2, 'tackle')

      @controller.makeMove(@player1, 'counter')
      @controller.makeMove(@player2, 'splash')

      mock.restore()
      mock.verify()

  describe "Perish Song", ->
    it "attaches to every pokemon in the field", ->
      shared.create.call(this)
      @controller.makeMove(@player1, 'perish-song')
      @controller.makeMove(@player2, 'splash')

      result = _.all @battle.getActivePokemon(), (pokemon) ->
        pokemon.hasAttachment(Attachment.PerishSong)
      result.should.be.true

    it "faints pokemon at the end of 4 turns", ->
      shared.create.call(this)
      @controller.makeMove(@player1, 'perish-song')
      @controller.makeMove(@player2, 'splash')

      @controller.makeMove(@player1, 'splash')
      @controller.makeMove(@player2, 'splash')

      @controller.makeMove(@player1, 'splash')
      @controller.makeMove(@player2, 'splash')

      result = _.all @battle.getActivePokemon(), (pokemon) ->
        !pokemon.isFainted()
      result.should.be.true

      @controller.makeMove(@player1, 'splash')
      @controller.makeMove(@player2, 'splash')

      result = _.all @battle.getActivePokemon(), (pokemon) ->
        pokemon.isFainted()
      result.should.be.true

  describe "Techno Blast", ->
    it "is Fire-type if the user holds a Burn Drive", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Burn Drive")]
      move = moves['techno-blast']
      type = move.getType(@battle, @team1.first(), @team2.first())
      type.should.equal "Fire"

    it "is Water-type if the user holds a Douse Drive", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Douse Drive")]
      move = moves['techno-blast']
      type = move.getType(@battle, @team1.first(), @team2.first())
      type.should.equal "Water"

    it "is Electric-type if the user holds a Shock Drive", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Shock Drive")]
      move = moves['techno-blast']
      type = move.getType(@battle, @team1.first(), @team2.first())
      type.should.equal "Electric"

    it "is Normal-type otherwise", ->
      shared.create.call(this)
      move = moves['techno-blast']
      type = move.getType(@battle, @team1.first(), @team2.first())
      type.should.equal "Normal"

  describe "Synchronoise", ->
    it "fails on Pokemon not of the user's type", ->
      shared.create.call this,
        team1: [Factory("Magikarp")]
        team2: [Factory("Celebi")]

      move = moves['synchronoise']
      mock = sinon.mock(move)
      mock.expects('fail').once()

      @controller.makeMove(@player1, "Synchronoise")
      @controller.makeMove(@player2, "Splash")

      mock.restore()
      mock.verify()

    it "works on Pokemon that share one type with the user", ->
      shared.create.call this,
        team1: [Factory("Ferrothorn")]
        team2: [Factory("Celebi")]

      hp = @team2.first().currentHP

      @controller.makeMove(@player1, "Synchronoise")
      @controller.makeMove(@player2, "Splash")

      @team2.first().currentHP.should.be.lessThan hp

  describe "Roost", ->
    shared.shouldDoNoDamage('Roost')

    it "removes the user's flying type during the turn", ->
      shared.create.call this,
        team1: [Factory("Gliscor")]

      newTypes = []
      oldAttach = @team1.first().attach
      @team1.first().attach = (args...) =>
        ret = oldAttach.apply(@team1.first(), args)
        newTypes = @team1.first().types
        ret

      @team1.first().currentHP = 1
      @controller.makeMove(@player1, "Roost")
      @controller.makeMove(@player2, "Splash")

      ('Flying' in newTypes).should.be.false
      newTypes.should.eql ['Ground']

    it "turns pure-Flying pokemon into Normal pokemon", ->
      shared.create.call this,
        team1: [Factory("Tornadus (incarnate)")]

      newTypes = []
      oldAttach = @team1.first().attach
      @team1.first().attach = (args...) =>
        ret = oldAttach.apply(@team1.first(), args)
        newTypes = @team1.first().types
        ret

      @team1.first().currentHP = 1
      @controller.makeMove(@player1, "Roost")
      @controller.makeMove(@player2, "Splash")

      ('Flying' in newTypes).should.be.false
      newTypes.should.eql ['Normal']

    it "keeps the user's types the same if non-Flying", ->
      shared.create.call this,
        team1: [Factory("Celebi")]

      oldTypes = @team1.first().types
      newTypes = []
      oldAttach = @team1.first().attach
      @team1.first().attach = (args...) =>
        ret = oldAttach.apply(@team1.first(), args)
        newTypes = @team1.first().types
        ret

      @team1.first().currentHP = 1
      @controller.makeMove(@player1, "Roost")
      @controller.makeMove(@player2, "Splash")

      newTypes.should.eql oldTypes

    it "restores the user's old types after the turn", ->
      shared.create.call this,
        team1: [Factory("Gliscor")]

      @team1.first().currentHP = 1
      @controller.makeMove(@player1, "Roost")
      @controller.makeMove(@player2, "Splash")

      ('Flying' in @team1.first().types).should.be.true

  describe 'Encore', ->
    shared.shouldDoNoDamage('Encore')

    it "fails if the target has not yet used a move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", evs: {speed: 4})]

      move = moves['encore']
      mock = sinon.mock(move)
      mock.expects('fail').once()

      @controller.makeMove(@player1, "Encore")
      @controller.makeMove(@player2, "Splash")

      mock.restore()
      mock.verify()

    it "forces the target to repeat its last used move", ->
      shared.create.call this,
        team2: [Factory("Magikarp", evs: {speed: 4})]

      @controller.makeMove(@player1, "Encore")
      @controller.makeMove(@player2, "Splash")

      @team2.first().validMoves().should.eql [ moves['splash'] ]

    it "changes the target's decision if it has not moved yet", ->
      shared.create.call this,
        team1: [Factory("Magikarp", evs: {speed: 4})]

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Splash")

      @controller.makeMove(@player1, "Encore")
      @controller.makeMove(@player2, "Tackle")

      @team2.first().lastMove.should.equal moves['splash']

    it "lasts 3 turns", ->
      shared.create.call this,
        team2: [Factory("Magikarp", evs: {speed: 4})]

      @controller.makeMove(@player1, "Encore")
      @controller.makeMove(@player2, "Splash")

      @team2.first().hasAttachment(Attachment.Encore).should.be.true

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Splash")

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Splash")

      @team2.first().hasAttachment(Attachment.Encore).should.be.false

    it "fails on certain moves like mimic", ->
      shared.create.call this,
        team2: [Factory("Magikarp", evs: {speed: 4})]

      move = moves['encore']
      mock = sinon.mock(move)
      mock.expects('fail').once()

      @controller.makeMove(@player1, "Encore")
      @controller.makeMove(@player2, "Mimic")

      mock.restore()
      mock.verify()

    it "fails if the pokemon is already encored", ->
      shared.create.call this,
        team2: [Factory("Magikarp", evs: {speed: 4})]

      move = moves['encore']
      mock = sinon.mock(move)
      mock.expects('fail').once()

      @controller.makeMove(@player1, "Encore")
      @controller.makeMove(@player2, "Splash")

      @controller.makeMove(@player1, "Encore")
      @controller.makeMove(@player2, "Splash")

      mock.restore()
      mock.verify()

    it "fails if the move has 0 PP", ->
      shared.create.call this,
        team2: [Factory("Magikarp", evs: {speed: 4})]

      move = moves['encore']
      mock = sinon.mock(move)
      mock.expects('fail').once()

      @team2.first().setPP(moves['splash'], 1)
      @controller.makeMove(@player1, "Encore")
      @controller.makeMove(@player2, "Splash")

      mock.restore()
      mock.verify()

    it "removes itself if the pokemon's move reaches 0 PP", ->
      shared.create.call this,
        team2: [Factory("Magikarp", evs: {speed: 4})]

      @team2.first().setPP(moves['splash'], 2)
      @controller.makeMove(@player1, "Encore")
      @controller.makeMove(@player2, "Splash")

      @team2.first().hasAttachment(Attachment.Encore).should.be.true

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Splash")

      @team2.first().hasAttachment(Attachment.Encore).should.be.false

  describe "Swagger", ->
    it "confuses the target", ->
      shared.create.call(this)

      @controller.makeMove(@player1, "Swagger")
      @controller.makeMove(@player2, "Splash")

      @team2.first().hasAttachment(Attachment.Confusion).should.be.true

    it "boosts the target's attack by two stages", ->
      shared.create.call(this)

      @controller.makeMove(@player1, "Swagger")
      @controller.makeMove(@player2, "Splash")

      @team2.first().stages.attack.should.equal -2

  describe "Flatter", ->
    it "confuses the target", ->
      shared.create.call(this)

      @controller.makeMove(@player1, "Flatter")
      @controller.makeMove(@player2, "Splash")

      @team2.first().hasAttachment(Attachment.Confusion).should.be.true

    it "boosts the target's special attack by two stages", ->
      shared.create.call(this)

      @controller.makeMove(@player1, "Flatter")
      @controller.makeMove(@player2, "Splash")

      @team2.first().stages.specialAttack.should.equal -2

  describe "Torment", ->
    it "prevents the target from using its last move", ->
      shared.create.call(this)

      @controller.makeMove(@player1, "Torment")
      @controller.makeMove(@player2, "Splash")

      @team2.first().validMoves().should.eql [ moves['tackle'] ]

      @controller.makeMove(@player1, "Splash")
      @controller.makeMove(@player2, "Tackle")

      @team2.first().validMoves().should.eql [ moves['splash'] ]

    it "still works even if a new pokemon has just switched in", ->
      shared.create.call(this, team2: [Factory("Magikarp"), Factory("Magikarp")])

      @controller.makeMove(@player1, "Torment")
      @controller.makeSwitch(@player2, 1)

      @team2.first().validMoves().should.eql [ moves['splash'], moves['tackle'] ]

    # TODO: Is this correct behavior?
    it "fails if the pokemon is already under Torment", ->
      shared.create.call(this)

      mock = sinon.mock(moves['torment'])
      mock.expects('fail').once()

      @controller.makeMove(@player1, "Torment")
      @controller.makeMove(@player2, "Splash")

      @controller.makeMove(@player1, "Torment")
      @controller.makeMove(@player2, "Tackle")

      mock.restore()
      mock.verify()

    xit "does not force the Outrage user to struggle", ->
    xit "does not prevent consecutive use of Struggle", ->

  describe "Psych Up", ->
    it "copies the target's stat changes", ->
      shared.create.call(this)

      @team1.first().stages.specialAttack = 5
      @team1.first().stages.evasion = 2
      @team2.first().stages.attack = 6
      @team2.first().stages.defense = -2
      @team2.first().stages.speed = -1
      @controller.makeMove(@player1, "Psych Up")
      @controller.makeMove(@player2, "Splash")
      @team1.first().stages.should.eql {
        attack: 6, defense: -2, specialAttack: 0, specialDefense: 0,
        speed: -1, accuracy: 0, evasion: 0
      }

  describe "Spikes", ->
    it "puts a layer of spikes on the opponents' field", ->
      shared.create.call(this)

      @team2.hasAttachment(Attachment.Spikes).should.be.false

      @controller.makeMove(@player1, "Spikes")
      @controller.makeMove(@player2, "Splash")

      @team2.hasAttachment(Attachment.Spikes).should.be.true

    it "fails if there are 3 layers", ->
      shared.create.call(this)

      mock = sinon.mock(moves['spikes'])
      mock.expects('fail').once()

      for i in [1..4]
        @controller.makeMove(@player1, "Spikes")
        @controller.makeMove(@player2, "Splash")

      mock.restore()
      mock.verify()

    it "does damage to pokemon switching in according to # of layers", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Magikarp")]

      hp = @team2.first().stat('hp')
      @controller.makeMove(@player1, "Spikes")
      @controller.makeMove(@player2, "Splash")

      @controller.makeMove(@player1, "Spikes")
      @controller.makeSwitch(@player2, 1)

      (hp - @team2.first().currentHP).should.equal Math.floor(hp / 8)
      @team2.first().currentHP = hp

      @controller.makeMove(@player1, "Spikes")
      @controller.makeSwitch(@player2, 1)

      (hp - @team2.first().currentHP).should.equal Math.floor(hp / 6)
      @team2.first().currentHP = hp

      @controller.makeMove(@player1, "Spikes")
      @controller.makeSwitch(@player2, 1)

      (hp - @team2.first().currentHP).should.equal Math.floor(hp / 4)

    it "does not affect pokemon with immunity to ground", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Magikarp", item: "Air Balloon")]

      @controller.makeMove(@player1, "Spikes")
      @controller.makeMove(@player2, "Splash")

      @controller.makeMove(@player1, "Spikes")
      @controller.makeSwitch(@player2, 1)

      @team2.first().currentHP.should.equal @team2.first().stat('hp')

  describe "Stealth Rock", ->
    it "puts a layer of rocks on the opponents' field", ->
      shared.create.call(this)

      @team2.hasAttachment(Attachment.StealthRock).should.be.false

      @controller.makeMove(@player1, "Stealth Rock")
      @controller.makeMove(@player2, "Splash")

      @team2.hasAttachment(Attachment.StealthRock).should.be.true

    it "fails if there is already rocks on the field", ->
      shared.create.call(this)

      mock = sinon.mock(moves['stealth-rock'])
      mock.expects('fail').once()

      @controller.makeMove(@player1, "Stealth Rock")
      @controller.makeMove(@player2, "Splash")

      @controller.makeMove(@player1, "Stealth Rock")
      @controller.makeMove(@player2, "Splash")

      mock.restore()
      mock.verify()

    it "does damage to pokemon switching in according to type", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Moltres")]

      @controller.makeMove(@player1, "Stealth Rock")
      @controller.makeMove(@player2, "Splash")

      @controller.makeMove(@player1, "Splash")
      @controller.makeSwitch(@player2, 1)

      hp = @team2.first().stat('hp')
      (hp - @team2.first().currentHP).should.equal Math.floor(hp / 2)

      @controller.makeMove(@player1, "Splash")
      @controller.makeSwitch(@player2, 1)

      hp = @team2.first().stat('hp')
      (hp - @team2.first().currentHP).should.equal Math.floor(hp / 8)

  describe "Toxic Spikes", ->
    it "puts a layer of toxic spikes on the opponents' field", ->
      shared.create.call(this)

      @team2.hasAttachment(Attachment.ToxicSpikes).should.be.false

      @controller.makeMove(@player1, "Toxic Spikes")
      @controller.makeMove(@player2, "Splash")

      @team2.hasAttachment(Attachment.ToxicSpikes).should.be.true

    it "fails if there are 2 layers", ->
      shared.create.call(this)

      mock = sinon.mock(moves['toxic-spikes'])
      mock.expects('fail').once()

      for i in [1..3]
        @controller.makeMove(@player1, "Toxic Spikes")
        @controller.makeMove(@player2, "Splash")

      mock.restore()
      mock.verify()

    it "poisons or severely poisons the switch-in if not immune", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Magikarp")]

      @controller.makeMove(@player1, "Toxic Spikes")
      @controller.makeMove(@player2, "Splash")

      @controller.makeSwitch(@player2, 1)
      @controller.makeMove(@player1, "Toxic Spikes")

      @team2.first().hasStatus(Status.POISON).should.be.true

      @controller.makeSwitch(@player2, 1)
      @controller.makeMove(@player1, "Splash")

      @team2.first().hasStatus(Status.TOXIC).should.be.true

    it "does not affect the pokemon if it's immune", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Ferrothorn")]

      @controller.makeMove(@player1, "Toxic Spikes")
      @controller.makeMove(@player2, "Splash")

      @controller.makeSwitch(@player2, 1)
      @controller.makeMove(@player1, "Splash")

      @team2.first().hasStatus(Status.POISON).should.be.false

    it "disappears if the pokemon switching in is a grounded Poison", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Drapion")]

      @controller.makeMove(@player1, "Toxic Spikes")
      @controller.makeMove(@player2, "Splash")

      @controller.makeSwitch(@player2, 1)
      @controller.makeMove(@player1, "Splash")

      @team2.hasAttachment(Attachment.ToxicSpikes).should.be.false

    it "doesn't disappear if the pokemon switching in is a flying Poison", ->
      shared.create.call this,
        team2: [Factory("Magikarp"), Factory("Drapion", item: "Air Balloon")]

      @controller.makeMove(@player1, "Toxic Spikes")
      @controller.makeMove(@player2, "Splash")

      @controller.makeSwitch(@player2, 1)
      @controller.makeMove(@player1, "Splash")

      @team2.hasAttachment(Attachment.ToxicSpikes).should.be.true

  testWeatherMove = (moveName, weather, item) ->
    describe moveName, ->
      it "changes the weather to #{weather.toLowerCase()} for 5 turns", ->
        shared.create.call(this)

        @controller.makeMove(@player1, moveName)
        @controller.makeMove(@player2, "Splash")

        @battle.weather.should.equal(weather)
        @battle.weatherDuration.should.equal 4

      it "changes the weather to #{weather.toLowerCase()} for 8 turns if user holds a #{item}", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: item)]

        @controller.makeMove(@player1, moveName)
        @controller.makeMove(@player2, "Splash")

        @battle.weather.should.equal(weather)
        @battle.weatherDuration.should.equal 7

  testWeatherMove("Rain Dance", Weather.RAIN, "Damp Rock")
  testWeatherMove("Sunny Day",  Weather.SUN,  "Heat Rock")
  testWeatherMove("Hail",       Weather.HAIL, "Icy Rock")
  testWeatherMove("Sandstorm",  Weather.SAND, "Smooth Rock")

  testStatusMove = (moveName, status) ->
    describe moveName, ->
      it "changes the status on a Pokemon if it has no status", ->
        shared.create.call(this)

        move = @battle.getMove(moveName)
        @battle.performMove(@id1, move)

        @team2.first().hasStatus(status).should.be.true

      it "does not change the status if Pokemon already has a status", ->
        shared.create.call(this)

        oldStatus = if status == Status.PARALYZE
            Status.SLEEP
          else
            Status.PARALYZE
        @team2.first().setStatus(oldStatus)

        move = @battle.getMove(moveName)
        @battle.performMove(@id1, move)

        @team2.first().hasStatus(status).should.be.false
        @team2.first().hasStatus(oldStatus).should.be.true

  testStatusMove("Dark Void", Status.SLEEP)
  testStatusMove("GrassWhistle", Status.SLEEP)
  testStatusMove("Hypnosis", Status.SLEEP)
  testStatusMove("Lovely Kiss", Status.SLEEP)
  testStatusMove("Poison Gas", Status.POISON)
  testStatusMove("PoisonPowder", Status.POISON)
  testStatusMove("Sing", Status.SLEEP)
  testStatusMove("Sleep Powder", Status.SLEEP)
  testStatusMove("Spore", Status.SLEEP)
  testStatusMove("Stun Spore", Status.PARALYZE)
  testStatusMove("Thunder Wave", Status.PARALYZE)
  testStatusMove("Toxic", Status.TOXIC)
  testStatusMove("Will-O-Wisp", Status.BURN)

  testEffectMove = (moveName, Effect) ->
    describe moveName, ->
      it "adds the effect to the Pokemon if it doesn't have it", ->
        shared.create.call(this)

        move = @battle.getMove(moveName)
        @battle.performMove(@id1, move)

        @team2.first().hasAttachment(Effect).should.be.true

      it "fails if the Pokemon already has it", ->
        shared.create.call(this)

        move = moves[moveName.toLowerCase().replace(/\s+/g, '-')]
        mock = sinon.mock(move)
        mock.expects('fail').once()

        shared.biasRNG.call(this, "randInt", 'confusion turns', 4)
        @team2.first().attach(Effect, {@battle})

        move = @battle.getMove(moveName)
        @battle.performMove(@id1, move)

        mock.restore()
        mock.verify()

  testEffectMove 'Confuse Ray', Attachment.Confusion
  testEffectMove 'Supersonic', Attachment.Confusion
  testEffectMove 'Sweet Kiss', Attachment.Confusion
  testEffectMove 'Teeter Dance', Attachment.Confusion

  describe "Trump Card", ->
    it "has 40 base power by default", ->
      shared.create.call(this)

      moves['trump-card'].basePower(@battle, @team1.first(), @team2.first()).should.equal 40

    it "has 50 base power if the move has 3 PP after use", ->
      shared.create.call this,
        team1: [Factory("Corphish")]

      pp = @team1.first().pp(moves['trump-card'])
      for x in [0...pp - 3]
        @team1.first().reducePP(moves['trump-card'])
      @team1.first().pp(moves['trump-card']).should.equal 3

      moves['trump-card'].basePower(@battle, @team1.first(), @team2.first()).should.equal 50

    it "has 60 base power if the move has 2 PP after use", ->
      shared.create.call this,
        team1: [Factory("Corphish")]

      pp = @team1.first().pp(moves['trump-card'])
      for x in [0...pp - 2]
        @team1.first().reducePP(moves['trump-card'])
      @team1.first().pp(moves['trump-card']).should.equal 2

      moves['trump-card'].basePower(@battle, @team1.first(), @team2.first()).should.equal 60

    it "has 80 base power if the move has 1 PP after use", ->
      shared.create.call this,
        team1: [Factory("Corphish")]

      pp = @team1.first().pp(moves['trump-card'])
      for x in [0...pp - 1]
        @team1.first().reducePP(moves['trump-card'])
      @team1.first().pp(moves['trump-card']).should.equal 1

      moves['trump-card'].basePower(@battle, @team1.first(), @team2.first()).should.equal 80

    it "has 200 base power if the move has 0 PP after use", ->
      shared.create.call this,
        team1: [Factory("Corphish")]

      pp = @team1.first().pp(moves['trump-card'])
      for x in [0...pp - 0]
        @team1.first().reducePP(moves['trump-card'])
      @team1.first().pp(moves['trump-card']).should.equal 0

      moves['trump-card'].basePower(@battle, @team1.first(), @team2.first()).should.equal 200

  testRandomSwitchMove = (moveName) ->
    describe moveName, ->
      it "should switch opponent out to a random member", ->
        shared.create.call(this, team2: [Factory("Magikarp"), Factory("Abra")])

        target = @team2.at(1)
        move = @battle.getMove(moveName)
        @battle.performMove(@id1, move)

        @team2.first().should.equal target

      it "should not force switches if opponent is the last pokemon", ->
        shared.create.call(this, team2: [Factory("Magikarp")])

        mock = sinon.mock(@battle.getOwner(@team2.first()))
        mock.expects("switch").never()

        move = @battle.getMove(moveName)
        @battle.performMove(@id1, move)

        mock.restore()
        mock.verify()

  testRandomSwitchMove "Roar"
  testRandomSwitchMove "Whirlwind"
  testRandomSwitchMove "Dragon Tail"
  testRandomSwitchMove "Circle Throw"

  testTrappingMove = (name) ->
    describe name, ->
      it "blocks switching", ->
        shared.create.call(this)

        @controller.makeMove(@player1, name)
        @controller.makeMove(@player2, "Splash")

        @team2.first().isSwitchBlocked().should.be.true
        @team2.first().hasAttachment(Attachment.Trap).should.be.true
        @team1.first().hasAttachment(Attachment.TrapLeash).should.be.true

      it "deals 1/16 of the pokemon's max hp every turn", ->
        shared.create.call(this, team2: [Factory("Blissey")])

        @controller.makeMove(@player1, name)
        @controller.makeMove(@player2, "Recover") # todo: make this rest instead once rest is implemented

        maxHP = @team2.first().stat('hp')
        expected = maxHP - Math.floor(maxHP / 16)
        @team2.first().currentHP.should.equal expected

      it "lasts several turns", ->
        shared.create.call(this, team2: [Factory("Blissey")])
        shared.biasRNG.call(this, "randInt", 'trapping move', 5)

        @controller.makeMove(@player1, name)
        @controller.makeMove(@player2, "Recover") # Shake off the initial damage

        # loop for 5 more turns. One of the turns has already passed.
        # These moves hurt for 5 moves and wear off on the 6th.
        for i in [1..5]
          @team2.first().hasAttachment(Attachment.Trap).should.be.true
          @controller.makeMove(@player1, "Splash")
          @controller.makeMove(@player2, "Splash")

        # Test if the actual damage checks out. It should have damaged only 5 times
        maxHP = @team2.first().stat('hp')
        expected = maxHP - (Math.floor(maxHP / 16) * 5)
        @team2.first().currentHP.should.equal expected

      it "wears off after a certain number of turns", ->
        shared.create.call(this, team2: [Factory("Blissey")])
        shared.biasRNG.call(this, "randInt", 'trapping move', 5)

        @controller.makeMove(@player1, name)
        @controller.makeMove(@player2, "Splash")

        # loop for 5 more turns. One of the turns has already passed.
        # These moves hurt for 5 moves and wear off on the 6th. We need
        # turn number 6 to pass before the attachment should wear off.
        for i in [1..5]
          @controller.makeMove(@player1, "Splash")
          @controller.makeMove(@player2, "Splash")

        @team2.first().isSwitchBlocked().should.be.false
        @team2.first().hasAttachment(Attachment.Trap).should.be.false
        @team1.first().hasAttachment(Attachment.TrapLeash).should.be.false

      it "does not reset the duration if used twice", ->
        shared.create.call(this, team2: [Factory("Blissey")])
        shared.biasRNG.call(this, "randInt", 'trapping move', 5)

        @controller.makeMove(@player1, name)
        @controller.makeMove(@player2, "Splash")

        @controller.makeMove(@player1, name)
        @controller.makeMove(@player2, "Splash")

        # loop for 4 more turns. These moves wear off after numTurns + 1.
        # 2 have already passed.
        for i in [1..4]
          @controller.makeMove(@player1, "Splash")
          @controller.makeMove(@player2, "Splash")

        @team2.first().isSwitchBlocked().should.be.false
        @team2.first().hasAttachment(Attachment.Trap).should.be.false
        @team1.first().hasAttachment(Attachment.TrapLeash).should.be.false

      it "wears off if the user switches", ->
        shared.create.call(this, team1: [Factory("Blissey"), Factory("Magikarp")])

        @controller.makeMove(@player1, name)
        @controller.makeMove(@player2, "Recover") # todo: make this rest instead once rest is implemented

        @controller.makeSwitch(@player1, 1)
        @controller.makeMove(@player2, "Splash")

        @team2.first().isSwitchBlocked().should.be.false
        @team2.first().hasAttachment(Attachment.Trap).should.be.false

      it "is always 7 turns if the user is holding grip claw", ->
        shared.create.call(this, team1: [Factory("Magikarp", item: "Grip Claw")])
        shared.biasRNG.call(this, "randInt", 'trapping move', 5)

        move = @battle.getMove(name)
        @battle.performMove(@id1, move)
        @battle.performMove(@id2, @battle.getMove("Recover"))

        # The user is damaged 7 times, but the attachment actually lasts
        # for 8 turns including the turn it is first used.
        for i in [1..8]
          @team2.first().hasAttachment(Attachment.Trap).should.be.true
          @battle.endTurn()

        @team2.first().hasAttachment(Attachment.Trap).should.be.false

  testTrappingMove "Bind"
  testTrappingMove "Clamp"
  testTrappingMove "Fire Spin"
  testTrappingMove "Magma Storm"
  testTrappingMove "Sand Tomb"
  testTrappingMove "Wrap"

  describe "Attract", ->
    shared.shouldDoNoDamage('Attract')

    it "has a 50% chance to immobilize a pokemon", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "M", evs: {speed: 4})]
        team2: [Factory("Magikarp", gender: "F")]
      shared.biasRNG.call(this, "next", 'attract chance', 0)  # 100% immobilizes

      mock = sinon.mock(moves['tackle'])
      mock.expects('execute').never()

      @controller.makeMove(@player1, 'Attract')
      @controller.makeMove(@player2, 'Tackle')

      mock.restore()
      mock.verify()

    it "has a 50% chance to not immobilize a pokemon", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "M", evs: {speed: 4})]
        team2: [Factory("Magikarp", gender: "F")]
      shared.biasRNG.call(this, "next", 'attract chance', .5)  # 0% immobilizes

      mock = sinon.mock(moves['tackle'])
      mock.expects('execute').once()

      @controller.makeMove(@player1, 'Attract')
      @controller.makeMove(@player2, 'Tackle')

      mock.restore()
      mock.verify()

    it "fails if used twice", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "M", evs: {speed: 4})]
        team2: [Factory("Magikarp", gender: "F")]

      mock = sinon.mock(moves['attract'])
      mock.expects('fail').once()

      @controller.makeMove(@player1, 'Attract')
      @controller.makeMove(@player2, 'Splash')

      @controller.makeMove(@player1, 'Attract')
      @controller.makeMove(@player2, 'Splash')

      mock.restore()
      mock.verify()

    it "fails if the Pokemon are not opposite genders", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "F")]
        team2: [Factory("Magikarp", gender: "F")]

      mock = sinon.mock(moves['attract'])
      mock.expects('fail').once()

      @controller.makeMove(@player1, 'Attract')
      @controller.makeMove(@player2, 'Splash')

      mock.restore()
      mock.verify()

  describe "Reflect", ->
    it "halves physical damage", ->
      shared.create.call(this)
      move = moves['tackle']
      mod = finalModifier.run(move, @battle, @team1.first(), @team2.first())
      mod.should.equal 0x1000

      @team2.attach(Attachment.Reflect)
      mod = finalModifier.run(move, @battle, @team1.first(), @team2.first())
      mod.should.equal 0x800

    it "does not halve non-physical damage", ->
      shared.create.call(this)
      move = moves['thundershock']
      mod = finalModifier.run(move, @battle, @team1.first(), @team2.first())
      mod.should.equal 0x1000

      @team2.attach(Attachment.Reflect)
      mod = finalModifier.run(move, @battle, @team1.first(), @team2.first())
      mod.should.equal 0x1000

    it "lasts five turns", ->
      shared.create.call(this)

      @battle.performMove(@id1, moves['reflect'])

      for i in [1..5]
        @team1.hasAttachment(Attachment.Reflect).should.be.true
        @battle.endTurn()
      @team1.hasAttachment(Attachment.Reflect).should.be.false

    it "fails if the user already used it", ->
      shared.create.call(this)
      mock = sinon.mock(moves['reflect'])
      mock.expects('fail').once()

      @battle.performMove(@id1, moves['reflect'])
      @battle.performMove(@id1, moves['reflect'])

      mock.restore()
      mock.verify()

    it "does not trigger on critical hits"

  describe "Light Screen", ->
    it "halves special damage", ->
      shared.create.call(this)
      move = moves['thundershock']
      mod = finalModifier.run(move, @battle, @team1.first(), @team2.first())
      mod.should.equal 0x1000

      @team2.attach(Attachment.LightScreen)
      mod = finalModifier.run(move, @battle, @team1.first(), @team2.first())
      mod.should.equal 0x800

    it "does not halve non-physical damage", ->
      shared.create.call(this)
      move = moves['tackle']
      mod = finalModifier.run(move, @battle, @team1.first(), @team2.first())
      mod.should.equal 0x1000

      @team2.attach(Attachment.LightScreen)
      mod = finalModifier.run(move, @battle, @team1.first(), @team2.first())
      mod.should.equal 0x1000

    it "lasts five turns", ->
      shared.create.call(this)

      @battle.performMove(@id1, moves['light-screen'])

      for i in [1..5]
        @team1.hasAttachment(Attachment.LightScreen).should.be.true
        @battle.endTurn()
      @team1.hasAttachment(Attachment.LightScreen).should.be.false

    it "fails if the user already used it", ->
      shared.create.call(this)
      mock = sinon.mock(moves['light-screen'])
      mock.expects('fail').once()

      @battle.performMove(@id1, moves['light-screen'])
      @battle.performMove(@id1, moves['light-screen'])

      mock.restore()
      mock.verify()

    it "does not trigger on critical hits"

  describe "Rapid Spin", ->
    it "removes spikes", ->
      shared.create.call this

      @battle.performMove(@id1, @battle.getMove("Spikes"))
      @team2.hasAttachment(Attachment.Spikes).should.be.true

      @battle.performMove(@id2, @battle.getMove("Rapid Spin"))
      @team2.hasAttachment(Attachment.Spikes).should.be.false

    it "removes stealth rock", ->
      shared.create.call this

      @battle.performMove(@id1, @battle.getMove("Stealth Rock"))
      @team2.hasAttachment(Attachment.StealthRock).should.be.true

      @battle.performMove(@id2, @battle.getMove("Rapid Spin"))
      @team2.hasAttachment(Attachment.StealthRock).should.be.false

    it "removes toxic spikes", ->
      shared.create.call this

      @battle.performMove(@id1, @battle.getMove("Toxic Spikes"))
      @team2.hasAttachment(Attachment.ToxicSpikes).should.be.true

      @battle.performMove(@id2, @battle.getMove("Rapid Spin"))
      @team2.hasAttachment(Attachment.ToxicSpikes).should.be.false

    it "removes multiple layers of entry hazards", ->
      shared.create.call this

      @battle.performMove(@id1, @battle.getMove("Spikes"))
      @battle.performMove(@id1, @battle.getMove("Spikes"))
      @battle.performMove(@id1, @battle.getMove("Spikes"))
      @team2.hasAttachment(Attachment.Spikes).should.be.true

      @battle.performMove(@id2, @battle.getMove("Rapid Spin"))
      @team2.hasAttachment(Attachment.Spikes).should.be.false

    it "removes trapping moves", ->
      shared.create.call this

      @battle.performMove(@id1, @battle.getMove("Fire Spin"))

      @team2.first().hasAttachment(Attachment.Trap).should.be.true
      @team1.first().hasAttachment(Attachment.TrapLeash).should.be.true
      @battle.performMove(@id2, @battle.getMove("Rapid Spin"))
      @team2.first().hasAttachment(Attachment.Trap).should.be.false
      @team1.first().hasAttachment(Attachment.TrapLeash).should.be.false

    it "removes leech seed"
    it "does not remove entry hazards if the user faints from rough skin"

    it "does not remove entry hazards if the user faints from life orb", ->
      shared.create.call(this, team2: [Factory("Magikarp", item: "Life Orb")])

      @team2.first().currentHP = 1
      @battle.performMove(@id1, @battle.getMove("Spikes"))
      @battle.performMove(@id2, @battle.getMove("Rapid Spin"))

      @team2.hasAttachment(Attachment.Spikes).should.be.true

  describe "Brick Break", ->
    it "shatters Light Screen", ->
      shared.create.call(this)
      @team2.attach(Attachment.LightScreen)
      @battle.performMove(@id1, moves['brick-break'])
      @team2.hasAttachment(Attachment.LightScreen).should.be.false

    it "shatters Reflect", ->
      shared.create.call(this)
      @team2.attach(Attachment.Reflect)
      @battle.performMove(@id1, moves['brick-break'])
      @team2.hasAttachment(Attachment.Reflect).should.be.false

    it "shatters both at the same time", ->
      shared.create.call(this)
      @team2.attach(Attachment.Reflect)
      @team2.attach(Attachment.LightScreen)
      @battle.performMove(@id1, moves['brick-break'])
      @team2.hasAttachment(Attachment.Reflect).should.be.false
      @team2.hasAttachment(Attachment.LightScreen).should.be.false

    it "shatters before damage calculation", ->
      shared.create.call(this)
      move = @battle.getMove("Brick Break")
      damage = move.calculateDamage(@battle, @team1.first(), @team2.first())
      @team2.attach(Attachment.Reflect)
      @team2.attach(Attachment.LightScreen)

      spy = sinon.spy(move, 'calculateDamage')
      @battle.performMove(@id1, move)
      spy.restore()
      spy.returned(damage).should.be.true

    it "does not shatter if the target is immune", ->
      shared.create.call(this)
      @team2.attach(Attachment.Reflect)
      @team2.attach(Attachment.LightScreen)

      sinon.stub(@team2.first(), 'isImmune', -> true)
      @battle.performMove(@id1, moves['brick-break'])
      @team2.hasAttachment(Attachment.Reflect).should.be.true
      @team2.hasAttachment(Attachment.LightScreen).should.be.true

    it "does not shatter if Brick Break misses", ->
      shared.create.call(this)
      @team2.attach(Attachment.Reflect)
      @team2.attach(Attachment.LightScreen)

      shared.biasRNG.call(this, 'randInt', 'miss', 101)
      @battle.performMove(@id1, moves['brick-break'])
      @team2.hasAttachment(Attachment.Reflect).should.be.true
      @team2.hasAttachment(Attachment.LightScreen).should.be.true
