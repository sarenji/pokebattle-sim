sinon = require 'sinon'
{items, moves} = require('../data/bw')
{Battle, Pokemon, Status, VolatileStatus, ParalyzeAttachment} = require('../').server
{Factory} = require './factory'

describe 'Mechanics', ->
  create = (opts={}) ->
    @id1 = 'abcde'
    @id2 = 'fghij'
    @player1 = opts.player1 || {id: @id1, emit: ->}
    @player2 = opts.player2 || {id: @id2, emit: ->}
    team1   = opts.team1
    team2   = opts.team2
    players = [{player: @player1, team: team1},
               {player: @player2, team: team2}]
    @battle = new Battle('id', players: players)
    sinon.stub(@battle.rng, 'next', -> 1)          # no chs
    sinon.stub(@battle.rng, 'randInt', -> 0)       # always max damage
    @team1  = @battle.getTeam(@player1.id)
    @team2  = @battle.getTeam(@player2.id)

  describe 'splash', ->
    it 'does no damage', ->
      create.call this,
        team1: [Factory('Magikarp')]
        team2: [Factory('Magikarp')]
      defender = @team2.at(0)
      originalHP = defender.currentHP
      @battle.makeMove(@player1, 'splash')
      @battle.continueTurn()
      defender.currentHP.should.equal originalHP

  describe 'an attack missing', ->
    it 'deals no damage', ->
      create.call this,
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
      create.call this,
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
      create.call this,
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
      create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'aerial-ace')
      @battle.continueTurn()
      @team2.at(0).currentHP.should.be.below hp

  describe 'accuracy and evasion boosts', ->
    it 'heighten and lower the chances of a move hitting', ->
      create.call this,
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
      create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @team2.at(0).currentHP = 1
      spy = sinon.spy(@player2, 'emit')
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      spy.calledWith('request action').should.be.true

    it 'does not increment the turn count', ->
      create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      turn = @battle.turn
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      @battle.turn.should.not.equal turn + 1

    it 'removes the fainted pokemon from the action priority queue', ->
      create.call this,
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
      create.call this,
        team1: [Factory('Mew'), Factory('Heracross')]
        team2: [Factory('Hitmonchan'), Factory('Heracross')]
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      @battle.makeSwitchByName(@player2, 'Heracross')
      @team2.at(0).name.should.equal 'Heracross'

  describe 'secondary effect attacks', ->
    it 'can inflict effect on successful hit', ->
      create.call this,
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
      create.call this,
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
      create.call this,
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
      create.call this,
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
      create.call this,
        team1: [Factory('Conkeldurr')]
        team2: [Factory('Hitmonchan')]
      hp = @team1.at(0).currentHP = @team1.at(0).stat('hp')
      @battle.makeMove(@player1, 'drain-punch')
      @battle.continueTurn()
      (@team1.at(0).currentHP - hp).should.equal 0

  describe 'weight-based attacks', ->
    it 'has 80 base power if the pokemon is 50.2kg', ->
      create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Hitmonchan')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'grass-knot')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 94

    it 'has 120 base power if the pokemon is >200kg', ->
      create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'grass-knot')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 153

  describe 'a pokemon using a primary boosting move', ->
    it "doesn't do damage if base power is 0", ->
      create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Hitmonchan')]
      @battle.makeMove(@player1, 'dragon-dance')
      @battle.continueTurn()
      @team2.at(0).currentHP.should.equal @team2.at(0).stat('hp')

    it "deals damage and boosts stats if base power is >0", ->
      create.call this,
        team1: [Factory('Celebi')]
        team2: [Factory('Gyarados')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'leaf-storm')
      @battle.continueTurn()
      @team1.at(0).stages.specialAttack.should.equal -2
      (hp - @team2.at(0).currentHP).should.equal 178

    it "boosts the pokemon's stats", ->
      create.call this,
        team1: [Factory('Gyarados')]
        team2: [Factory('Hitmonchan')]
      attack = @team1.at(0).stat('attack')
      speed  = @team1.at(0).stat('speed')
      @battle.makeMove(@player1, 'dragon-dance')
      @battle.continueTurn()
      @team1.at(0).stages.should.include attack: 1, speed: 1

    it "has the boosts removed on switch"

  describe 'a pokemon using a move with a secondary boosting effect', ->
    it "has a chance to activate", ->
      create.call this,
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
      create.call this,
        team1: [Factory('Gliscor')]
        team2: [Factory('Regirock')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'acrobatics')
      @battle.continueTurn()
      damage = (hp - @team2.at(0).currentHP)
      damage.should.equal 36

    it 'has normal base power with an item', ->
      create.call this,
        team1: [Factory('Gliscor', item: 'Leftovers')]
        team2: [Factory('Regirock')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'acrobatics')
      @battle.continueTurn()
      damage = (hp - @team2.at(0).currentHP)
      damage.should.equal 18

  describe 'a pokemon using a standard recoil move', ->
    it 'receives a percentage of the damage rounded down', ->
      create.call this,
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
      create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @battle.makeMove(@player1, 'Ice Punch')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 84

    it "increases damage if the move has bp <= 60", ->
      create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Shaymin (land)')]
      @battle.makeMove(@player1, 'Bullet Punch')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 67

  describe 'STAB', ->
    it "gets applied if the move and user share a type", ->
      create.call this,
        team1: [Factory('Heracross')]
        team2: [Factory('Regirock')]
      @battle.makeMove(@player1, 'Megahorn')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 123

    it "doesn't get applied if the move and user are of different types", ->
      create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @battle.makeMove(@player1, 'Ice Punch')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 84

    it 'is 2x if the pokemon has Adaptability', ->
      create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Mew')]
      @battle.makeMove(@player1, 'Tri Attack')
      hp = @team2.at(0).currentHP
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 214

  describe 'turn order', ->
    it 'randomly decides winner if pokemon have the same speed and priority', ->
      create.call this,
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
      create.call this,
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
      create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Hitmonchan')]
      spy = sinon.spy(@battle, 'orderIds')
      @battle.makeMove(@player1, 'ThunderPunch')
      @battle.makeMove(@player2, 'ThunderPunch')
      spy.returned([@id2, @id1]).should.be.true

  describe 'fainting all the opposing pokemon', ->
    it "doesn't request any more actions from players", ->
      create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Mach Punch')
      @battle.makeMove(@player2, 'Psychic')
      @battle.requests.should.not.have.property @player1.id
      @battle.requests.should.not.have.property @player2.id

    it 'ends the battle', ->
      create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @team2.at(0).currentHP = 1
      mock = sinon.mock(@battle)
      mock.expects('endBattle').once()
      @battle.makeMove(@player1, 'Mach Punch')
      @battle.makeMove(@player2, 'Psychic')
      mock.verify()

  describe 'a pokemon using a hazing move', ->
    it 'removes all status boosts from each pokemon', ->
      create.call this,
        team1: [Factory('Weezing')]
        team2: [Factory('Mew')]
      # Create artificial boosts.
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
      create.call this,
        team1: [Factory('Blissey')]
        team2: [Factory('Mew')]
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'Seismic Toss')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 100

  describe 'Psywave', ->
    it 'does user.level/2 damage minimum', ->
      create.call this,
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
      create.call this,
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
      create.call this,
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
      create.call this,
        team1: [Factory('Zangoose')]
        team2: [Factory('Magikarp')]
      hp = @team2.at(0).currentHP
      @team1.at(0).attach(new ParalyzeAttachment())
      @battle.makeMove(@player1, 'Facade')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 324

  describe 'reversal and flail', ->
    it 'have 200 base power at 1 hp', ->
      create.call this,
        team1: [Factory('Zangoose')]
        team2: [Factory('Magikarp')]
      @team1.at(0).currentHP = 1
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'Flail')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 462

    it 'have 40 base power at 50% hp', ->
      create.call this,
        team1: [Factory('Zangoose')]
        team2: [Factory('Magikarp')]
      @team1.at(0).currentHP = Math.floor(@team1.at(0).stat('hp') / 2)
      hp = @team2.at(0).currentHP
      @battle.makeMove(@player1, 'Flail')
      @battle.continueTurn()
      (hp - @team2.at(0).currentHP).should.equal 94

  describe 'eruption and water spout', ->
    beforeEach ->
      create.call this,
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
      create.call this,
        team1: [Factory('Forretress', ivs: {speed: 0})]
        team2: [Factory('Jolteon', evs: {speed: 252}, nature: "Timid")]
      move = moves['gyro-ball']
      attacker = @team1.at(0)
      defender = @team2.at(0)
      attacker.stages.speed = -6
      move.basePower(@battle, attacker, defender).should.equal 150

    it 'has variable base power based on speed of target and user', ->
      create.call this,
        team1: [Factory('Electrode', evs: {speed: 252}, nature: "Jolly")]
        team2: [Factory('Magikarp', ivs: {speed: 0})]
      move = moves['gyro-ball']
      attacker = @team1.at(0)
      defender = @team2.at(0)
      attacker.stages.speed = -6
      move.basePower(@battle, attacker, defender).should.equal 40

  describe 'brine', ->
    it 'has normal base power if the target has over 50% HP', ->
      create.call this,
        team1: [Factory('Empoleon')]
        team2: [Factory('Magikarp')]
      move = moves['brine']
      @team2.at(0).currentHP = Math.floor(@team2.at(0).currentHP / 2) + 1
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 65

    it 'doubles base power if the target has 50% or less HP', ->
      create.call this,
        team1: [Factory('Empoleon')]
        team2: [Factory('Magikarp')]
      move = moves['brine']
      @team2.at(0).currentHP = Math.floor(@team2.at(0).currentHP / 2)
      move.basePower(@battle, @team1.at(0), @team2.at(0)).should.equal 130

  describe 'yawn', ->
    it 'gives the yawn attachment', ->
      create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Magikarp')]
      @battle.makeMove(@player1, 'Yawn')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).hasAttachment('YawnAttachment').should.be.true

    it 'puts the opponent to sleep at the end of the second turn', ->
      create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Magikarp')]
      @battle.makeMove(@player1, 'Yawn')
      @battle.makeMove(@player2, 'Splash')
      
      @battle.makeMove(@player1, 'Yawn')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).hasStatus(Status.SLEEP).should.be.true
      @battle.turn.should.equal 3

    it 'does not put the opponent to sleep at the end of the first turn', ->
      create.call this,
        team1: [Factory('Camerupt')]
        team2: [Factory('Magikarp')]
      @battle.makeMove(@player1, 'Yawn')
      @battle.makeMove(@player2, 'Splash')

      @team2.at(0).hasStatus(Status.SLEEP).should.be.false
      @battle.turn.should.equal 2
