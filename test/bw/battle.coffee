require '../helpers'

{Attachment} = require('../../server/bw/attachment')
{Battle} = require('../../server/bw/battle')
{BattleController} = require('../../server/bw/battle_controller')
{Pokemon} = require('../../server/bw/pokemon')
{Weather} = require('../../shared/weather')
{Conditions} = require '../../shared/conditions'
{Factory} = require('../factory')
{User} = require('../../server/user')
{Protocol} = require '../../shared/protocol'
shared = require('../shared')
should = require 'should'
sinon = require 'sinon'

describe 'Battle', ->
  beforeEach ->
    shared.create.call this,
      team1: [Factory('Hitmonchan'), Factory('Heracross')]
      team2: [Factory('Hitmonchan'), Factory('Heracross')]

  it 'starts at turn 1', ->
    @battle.turn.should.equal 1

  describe '#hasWeather(weatherName)', ->
    it 'returns true if the current battle weather is weatherName', ->
      @battle.weather = "Sunny"
      @battle.hasWeather("Sunny").should.be.true

    it 'returns false on non-None in presence of a weather-cancel ability', ->
      @battle.weather = "Sunny"
      @sandbox.stub(@battle, 'hasWeatherCancelAbilityOnField', -> true)
      @battle.hasWeather("Sunny").should.be.false

    it 'returns true on None in presence of a weather-cancel ability', ->
      @battle.weather = "Sunny"
      @sandbox.stub(@battle, 'hasWeatherCancelAbilityOnField', -> true)
      @battle.hasWeather("None").should.be.true

  describe '#recordMove', ->
    it "records a player's move", ->
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      action = @battle.pokemonActions.find((a) => a.pokemon == @p1)
      should.exist(action)
      action.should.have.property("move")
      action.move.should.equal @battle.getMove('Tackle')

    it "does not record a move if player has already made an action", ->
      length = @battle.pokemonActions.length
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.pokemonActions.length.should.equal(1 + length)

  describe '#undoCompletedRequest', ->
    it "fails if the player didn't make any action", ->
      @battle.undoCompletedRequest(@id1).should.be.false

    it "fails on the second turn as well if the player didn't make any action", ->
      @controller.makeMove(@id1, "Mach Punch")
      @controller.makeMove(@id2, "Mach Punch")
      @battle.turn.should.equal 2
      @battle.undoCompletedRequest(@id1).should.be.false

    it "succeeds if the player selected an action already", ->
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.pokemonActions.should.not.be.empty
      @battle.undoCompletedRequest(@id1).should.be.true
      @battle.pokemonActions.should.be.empty

    it "can cancel an action multiple times", ->
      for i in [0..5]
        @battle.recordMove(@id1, @battle.getMove('Tackle'))
        @battle.pokemonActions.should.not.be.empty
        @battle.undoCompletedRequest(@id1).should.be.true
        @battle.pokemonActions.should.be.empty

  describe '#recordSwitch', ->
    it "records a player's switch", ->
      @battle.recordSwitch(@id1, 1)
      action = @battle.pokemonActions.find((a) => a.pokemon == @p1)
      should.exist(action)
      action.should.have.property("to")
      action.to.should.equal 1

    it "does not record a switch if player has already made an action", ->
      length = @battle.pokemonActions.length
      @battle.recordSwitch(@id1, 1)
      @battle.recordSwitch(@id1, 1)
      @battle.pokemonActions.length.should.equal(1 + length)

  describe '#performSwitch', ->
    it "swaps pokemon positions of a player's team", ->
      [poke1, poke2] = @team1.pokemon
      @battle.performSwitch(@p1, 1)
      @team1.pokemon.slice(0, 2).should.eql [poke2, poke1]

    it "calls the pokemon's switchOut() method", ->
      pokemon = @p1
      mock = @sandbox.mock(pokemon)
      mock.expects('switchOut').once()
      @battle.performSwitch(@p1, 1)
      mock.verify()

  describe "#setWeather", ->
    it "can last a set number of turns", ->
      @battle.setWeather(Weather.SUN, 5)
      for i in [0...5]
        @battle.endTurn()
      @battle.weather.should.equal Weather.NONE

  describe "weather", ->
    it "damages pokemon who are not of a certain type", ->
      @battle.setWeather(Weather.SAND)
      @battle.endTurn()
      maxHP = @p1.stat('hp')
      (maxHP - @p1.currentHP).should.equal Math.floor(maxHP / 16)
      (maxHP - @p2.currentHP).should.equal Math.floor(maxHP / 16)

      @battle.setWeather(Weather.HAIL)
      @battle.endTurn()
      maxHP = @p1.stat('hp')
      (maxHP - @p1.currentHP).should.equal 2*Math.floor(maxHP / 16)
      (maxHP - @p2.currentHP).should.equal 2*Math.floor(maxHP / 16)

  describe "move PP", ->
    it "goes down after a pokemon uses a move", ->
      pokemon = @p1
      move = @p1.moves[0]
      @battle.performMove(@p1, move)
      @p1.pp(move).should.equal(@p1.maxPP(move) - 1)

  describe "#performMove", ->
    it "records this move as the battle's last move", ->
      move = @p1.moves[0]
      @battle.performMove(@p1, move)

      should.exist @battle.lastMove
      @battle.lastMove.should.equal move

  describe "#bump", ->
    it "bumps a pokemon to the front of its priority bracket", ->
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Splash'))
      @battle.determineTurnOrder()

      # Get last pokemon to move and bump it up
      {pokemon} = @battle.pokemonActions[@battle.pokemonActions.length - 1]
      @battle.bump(pokemon)
      @battle.pokemonActions[0].pokemon.should.eql pokemon

    it "bumps a pokemon to the front of a specific priority bracket", ->
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Mach Punch'))
      queue = @battle.determineTurnOrder()

      @battle.bump(@p1, @battle.getMove('Mach Punch').priority)
      queue[0].pokemon.should.eql @p1

    it "still works even if there's nothing in that bracket", ->
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Mach Punch'))
      queue = @battle.determineTurnOrder()

      queue.should.have.length(2)
      @battle.bump(@p1)
      queue.should.have.length(2)
      queue[0].pokemon.should.eql @p2
      queue[1].pokemon.should.eql @p1

  describe "#delay", ->
    it "delays a pokemon to the end of its priority bracket", ->
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Splash'))
      @battle.determineTurnOrder()

      # Get first pokemon to move and delay it
      {pokemon} = @battle.pokemonActions[0]
      @battle.delay(pokemon)
      @battle.pokemonActions[1].pokemon.should.eql pokemon

    it "delays a pokemon to the end of a specific priority bracket", ->
      @battle.recordMove(@id1, @battle.getMove('Mach Punch'))
      @battle.recordMove(@id2, @battle.getMove('Tackle'))
      queue = @battle.determineTurnOrder()

      @battle.delay(@p1, @battle.getMove('Tackle').priority)
      queue[1].pokemon.should.eql @p1

    it "still works even if there's nothing in that bracket", ->
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Mach Punch'))
      queue = @battle.determineTurnOrder()

      queue.should.have.length(2)
      @battle.delay(@p1)
      queue.should.have.length(2)
      queue[0].pokemon.should.eql @p2
      queue[1].pokemon.should.eql @p1

  describe "#weatherUpkeep", ->
    it "does not damage Pokemon if a weather-cancel ability is on the field", ->
      @battle.setWeather(Weather.HAIL)
      @sandbox.stub(@battle, 'hasWeatherCancelAbilityOnField', -> true)
      @battle.endTurn()
      @p1.currentHP.should.not.be.lessThan @p1.stat('hp')
      @p2.currentHP.should.not.be.lessThan @p2.stat('hp')

    it "does not damage a Pokemon who is immune to a weather", ->
      @battle.setWeather(Weather.HAIL)
      @sandbox.stub(@p2, 'isWeatherDamageImmune', -> true)
      @battle.endTurn()
      @p1.currentHP.should.be.lessThan @p1.stat('hp')
      @p2.currentHP.should.not.be.lessThan @p2.stat('hp')

  describe "#addSpectator", ->
    it "adds the spectator to an internal array", ->
      spectator = new User("derp")
      length = @battle.spectators.length
      @battle.addSpectator(spectator)
      @battle.spectators.should.have.length(length + 1)
      @battle.spectators.should.include(spectator)

    it "gives the spectator battle information", ->
      spectator = new User("derp")
      spy = @sandbox.spy(spectator, 'send')
      @battle.addSpectator(spectator)
      spectators = @battle.spectators.map((s) -> s.toJSON())
      {id, numActive, log} = @battle
      spy.calledWithMatch("spectateBattle", id, 'bw', numActive, null, @battle.playerIds, spectators, log).should.be.true

    it "receives the correct set of initial teams", ->
      spectator = new User("derp")
      spy = @sandbox.spy(spectator, 'send')
      teams = @battle.getTeams().map((team) -> team.toJSON(hidden: true))
      @team1.switch(@p1, 1)

      @battle.addSpectator(spectator)
      spectators = @battle.spectators.map((s) -> s.toJSON())
      {id, numActive, log} = @battle
      spy.calledWithMatch("spectateBattle", id, 'bw', numActive, null, @battle.playerIds, spectators, log).should.be.true

    it "does not add a spectator twice", ->
      spectator = new User("derp")
      length = @battle.spectators.length
      @battle.addSpectator(spectator)
      @battle.addSpectator(spectator)
      @battle.spectators.should.have.length(length + 1)

  describe "#removeSpectator", ->
    it "removes the spectator from the array", ->
      spectator = new User("guy")
      length = @battle.spectators.length
      @battle.addSpectator(spectator)
      @battle.spectators.should.have.length(length + 1)
      @battle.removeSpectator(spectator)
      @battle.spectators.should.have.length(length)

  describe "#getWinner", ->
    it "returns player 1 if player 2's team has all fainted", ->
      pokemon.faint()  for pokemon in @team2.pokemon
      @battle.getWinner().should.equal(@id1)

    it "returns player 2 if player 1's team has all fainted", ->
      pokemon.faint()  for pokemon in @team1.pokemon
      @battle.getWinner().should.equal(@id2)

    it "declares the pokemon dying of recoil the winner", ->
      shared.create.call this,
        team1: [Factory('Talonflame', moves: ["Brave Bird"])]
        team2: [Factory('Magikarp')]

      @p1.currentHP = @p2.currentHP = 1
      spy = @sandbox.spy(@battle, 'getWinner')
      @controller.makeMove(@id1, "Brave Bird")
      @controller.makeMove(@id2, "Splash")
      spy.returned(@id1).should.be.true

  describe "#endBattle", ->
    it "cannot end multiple times", ->
      spy = @sandbox.spy(@battle, 'emit')
      spy.withArgs("end")
      @battle.endBattle()
      @battle.endBattle()
      spy.withArgs("end").calledOnce.should.be.true

    it "marks the battle as over", ->
      @battle.endBattle()
      @battle.isOver().should.be.true

    it "updates the winner and losers' ratings", (done) ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
        conditions: [ Conditions.RATED_BATTLE ]
      ratings = require('../../server/ratings')
      @battle.on "ratingsUpdated", =>
        ratings.getPlayer @id1, (err, rating1) =>
          ratings.getPlayer @id2, (err, rating2) =>
            defaultPlayer = ratings.algorithm.createPlayer()
            rating1.rating.should.be.greaterThan(defaultPlayer.rating)
            rating2.rating.should.be.lessThan(defaultPlayer.rating)
            done()

      ratings.resetRatings [ @id1, @id2 ], =>
        @p2.currentHP = 1
        mock = @sandbox.mock(@controller)
        @controller.makeMove(@id1, 'Mach Punch')
        @controller.makeMove(@id2, 'Psychic')

    it "doesn't update ratings if an unrated battle", (done) ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      ratings = require('../../server/ratings')
      @battle.on 'end', =>
        ratings.getPlayer @id1, (err, rating1) =>
          ratings.getPlayer @id2, (err, rating2) =>
            rating1.rating.should.equal(0)
            rating2.rating.should.equal(0)
            done()

      ratings.resetRatings [ @id1, @id2 ], =>
        @p2.currentHP = 1
        mock = @sandbox.mock(@controller)
        @controller.makeMove(@id1, 'Mach Punch')
        @controller.makeMove(@id2, 'Psychic')

  describe "#forfeit", ->
    it "prematurely ends the battle", ->
      spy = @sandbox.spy(@battle, 'tell')
      spy.withArgs(Protocol.FORFEIT_BATTLE, @battle.getPlayerIndex(@id1))
      @battle.forfeit(@id1)
      spy.withArgs(Protocol.FORFEIT_BATTLE, @battle.getPlayerIndex(@id1))
        .called.should.be.true

    it "does not forfeit if the player given is invalid", ->
      mock = @sandbox.mock(@battle).expects('tell').never()
      @battle.forfeit('this definitely should not work')
      mock.verify()

    it "cannot forfeit multiple times", ->
      spy = @sandbox.spy(@battle, 'tell')
      spy.withArgs(Protocol.FORFEIT_BATTLE, @battle.getPlayerIndex(@id1))
      @battle.forfeit(@id1)
      @battle.forfeit(@id1)
      spy.withArgs(Protocol.FORFEIT_BATTLE, @battle.getPlayerIndex(@id1))
        .calledOnce.should.be.true

    it "marks the battle as over", ->
      @battle.forfeit(@id1)
      @battle.isOver().should.be.true

    it "updates the winner and losers' ratings if a rated battle", (done) ->
      shared.create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
        conditions: [ Conditions.RATED_BATTLE ]
      ratings = require('../../server/ratings')
      @battle.on "ratingsUpdated", =>
        ratings.getPlayer @id1, (err, rating1) =>
          ratings.getPlayer @id2, (err, rating2) =>
            defaultPlayer = ratings.algorithm.createPlayer()
            rating1.rating.should.be.greaterThan(defaultPlayer.rating)
            rating2.rating.should.be.lessThan(defaultPlayer.rating)
            done()
      ratings.resetRatings([ @id1, @id2 ], => @battle.forfeit(@id2))

    it "doesn't update the winner and losers' ratings if not a rated battle", (done) ->
      ratings = require('../../server/ratings')
      @battle.on 'end', =>
        ratings.getPlayer @id1, (err, rating1) =>
          ratings.getPlayer @id2, (err, rating2) =>
            rating1.rating.should.equal(0)
            rating2.rating.should.equal(0)
            done()
      ratings.resetRatings([ @id1, @id2 ], => @battle.forfeit(@id2))

  describe "#hasStarted", ->
    it "returns false if the battle has not started", ->
      battle = new Battle('id', [])
      battle.hasStarted().should.be.false

    it "returns true if the battle has started", ->
      battle = new Battle('id', [])
      battle.begin()
      battle.hasStarted().should.be.true

  describe "#getAllAttachments", ->
    it "returns a list of attachments for all pokemon, teams, and battles", ->
      @battle.attach(Attachment.TrickRoom)
      @team2.attach(Attachment.Reflect)
      @p1.attach(Attachment.Ingrain)
      attachments = @battle.getAllAttachments()
      should.exist(attachments)
      attachments = attachments.map((a) -> a.constructor)
      attachments.length.should.be.greaterThan(2)
      attachments.should.include(Attachment.TrickRoom)
      attachments.should.include(Attachment.Reflect)
      attachments.should.include(Attachment.Ingrain)

  describe "#query", ->
    it "queries all attachments attached to a specific event", ->
      @battle.attach(Attachment.TrickRoom)
      @team2.attach(Attachment.Reflect)
      @p1.attach(Attachment.Ingrain)
      mocks = []
      mocks.push @sandbox.mock(Attachment.TrickRoom.prototype)
      mocks.push @sandbox.mock(Attachment.Reflect.prototype)
      mocks.push @sandbox.mock(Attachment.Ingrain.prototype)
      mock.expects("endTurn").once()  for mock in mocks
      attachments = @battle.query("endTurn")
      mock.verify()  for mock in mocks

  describe "#getOpponents", ->
    it "returns all opponents of a particular pokemon as an array", ->
      @battle.getOpponents(@p1).should.be.an.instanceOf(Array)
      @battle.getOpponents(@p1).should.have.length(1)

    it "does not include fainted opponents", ->
      @p2.faint()
      @battle.getOpponents(@p1).should.have.length(0)

  describe "#sendRequestTo", ->
    it "sends all requests to a certain player", ->
      mock = @sandbox.mock(@battle).expects('tellPlayer').once()
      mock.withArgs(@id1, Protocol.REQUEST_ACTIONS)
      @battle.sendRequestTo(@id1)
      mock.verify()

  describe "expiration", ->
    beforeEach ->
      shared.create.call(this)

    it "ends ongoing battles after 24 hours", ->
      time = 24 * 60 * 60 * 1000
      @clock.tick(time)
      @battle.isOver().should.be.true

    it "sends BATTLE_EXPIRED after 48 hours after battle end", ->
      time = 48 * 60 * 60 * 1000
      delta = 5000
      spy = @sandbox.spy(@battle, 'tell').withArgs(Protocol.BATTLE_EXPIRED)
      @clock.tick(delta)
      @battle.forfeit(@id1)
      @battle.isOver().should.be.true
      spy.withArgs(Protocol.BATTLE_EXPIRED).called.should.be.false

      @battle.tell.restore()
      spy = @sandbox.spy(@battle, 'tell').withArgs(Protocol.BATTLE_EXPIRED)
      @clock.tick(time)
      @battle.isOver().should.be.true
      spy.withArgs(Protocol.BATTLE_EXPIRED).calledOnce.should.be.true

    it "doesn't call 'expire' if expiring twice", ->
      firstExpire = 24 * 60 * 60 * 1000
      secondExpire = 48 * 60 * 60 * 1000
      spy = @sandbox.spy(@battle, 'expire')
      @clock.tick(firstExpire)
      @battle.isOver().should.be.true
      @clock.tick(secondExpire)
      spy.calledOnce.should.be.true

    it "doesn't call 'end' twice", ->
      longExpire = 48 * 60 * 60 * 1000
      spy = @sandbox.spy()
      @battle.on('end', spy)
      @battle.forfeit(@id1)
      @battle.isOver().should.be.true

      @clock.tick(longExpire)
      spy.calledOnce.should.be.true
