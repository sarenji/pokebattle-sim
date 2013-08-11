{Battle, BattleController, Pokemon, Weather} = require('../').server
{Factory} = require('./factory')
{Protocol} = require '../shared/protocol'
should = require 'should'
require './helpers'

describe 'Battle', ->
  beforeEach ->
    @id1 = 'abcde'
    @id2 = 'fghij'
    @socket1 = {id: @id1, send: ->}
    @socket2 = {id: @id2, send: ->}
    team1   = [Factory('Hitmonchan'), Factory('Heracross')]
    team2   = [Factory('Hitmonchan'), Factory('Heracross')]
    players = [{player: @socket1, team: team1},
               {player: @socket2, team: team2}]
    @battle = new Battle('id', players: players)
    @controller = new BattleController(@battle)
    @team1  = @battle.getTeam(@id1)
    @team2  = @battle.getTeam(@id2)
    @player1 = @team1.player
    @player2 = @team2.player
    @p1     = @team1.first()
    @p2     = @team2.first()

    @controller.beginBattle()

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
      @battle.playerActions.should.have.property @id1
      @battle.playerActions[@id1].move.should.equal @battle.getMove('Tackle')

  describe '#recordSwitch', ->
    it "records a player's switch", ->
      @battle.recordSwitch(@id1, 1)
      @battle.playerActions.should.have.property @id1
      @battle.playerActions[@id1].to.should.equal 1

  describe '#performSwitch', ->
    it "swaps pokemon positions of a player's team", ->
      [poke1, poke2] = @team1.pokemon
      @battle.performSwitch(@id1, 1)
      @team1.pokemon.slice(0, 2).should.eql [poke2, poke1]

    it "calls the pokemon's switchOut() method", ->
      pokemon = @p1
      mock = @sandbox.mock(pokemon)
      mock.expects('switchOut').once()
      @battle.performSwitch(@id1, 1)
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
      move = pokemon.moves[0]
      @battle.performMove(@id1, move)
      pokemon.pp(move).should.equal(pokemon.maxPP(move) - 1)

  describe "#performMove", ->
    it "records this move as the battle's last move", ->
      pokemon = @p1
      move = pokemon.moves[0]
      @battle.performMove(@id1, move)

      should.exist @battle.lastMove
      @battle.lastMove.should.equal move

  describe "#bump", ->
    it "bumps a pokemon to the front of its priority bracket", ->
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Splash'))
      @battle.determineTurnOrder()

      # Get last pokemon to move and bump it up
      {pokemon} = @battle.priorityQueue[@battle.priorityQueue.length - 1]
      @battle.bump(pokemon)
      @battle.priorityQueue[0].pokemon.should.eql pokemon

    it "bumps a pokemon to the front of a specific priority bracket", ->
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Mach Punch'))
      queue = @battle.determineTurnOrder()

      @battle.bump(@p1, @battle.getMove('Mach Punch').priority)
      queue[0].pokemon.should.eql @p1

  describe "#delay", ->
    it "delays a pokemon to the end of its priority bracket", ->
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Splash'))
      @battle.determineTurnOrder()

      # Get first pokemon to move and delay it
      {pokemon} = @battle.priorityQueue[0]
      @battle.delay(pokemon)
      @battle.priorityQueue[1].pokemon.should.eql pokemon

    it "delays a pokemon to the end of a specific priority bracket", ->
      @battle.recordMove(@id1, @battle.getMove('Mach Punch'))
      @battle.recordMove(@id2, @battle.getMove('Tackle'))
      queue = @battle.determineTurnOrder()

      @battle.delay(@p1, @battle.getMove('Tackle').priority)
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
      spectator = {send: ->}
      @battle.addSpectator(spectator)
      @battle.spectators.should.have.length(1)
      @battle.spectators.should.includeEql(spectator)

    it "gives the spectator battle information", ->
      spectator = {send: ->}
      spy = @sandbox.spy(spectator, 'send')
      @battle.addSpectator(spectator)
      t = @battle.getTeams().map((team) -> team.toJSON())
      {id, numActive} = @battle
      spy.calledWithMatch("spectate battle", id, numActive, t).should.be.true

    it "does not add a spectator twice", ->
      spectator = {send: ->}
      @battle.addSpectator(spectator)
      @battle.addSpectator(spectator)
      @battle.spectators.should.have.length(1)

    it "does not add a player as a spectator", ->
      @battle.addSpectator(@socket1)
      @battle.addSpectator(@socket2)
      @battle.spectators.should.have.length(0)

  describe "#getWinner", ->
    it "returns null if there is no winner yet", ->
      should.not.exist @battle.getWinner()

    it "returns player 1 if player 2's team has all fainted", ->
      pokemon.faint()  for pokemon in @team2.pokemon
      @battle.getWinner().should.equal(@player1)

    it "returns player 2 if player 1's team has all fainted", ->
      pokemon.faint()  for pokemon in @team1.pokemon
      @battle.getWinner().should.equal(@player2)

  describe "#forfeit", ->
    it "prematurely ends the battle", ->
      mocks = []
      for player in [ @player1, @player2 ]
        mock = @sandbox.mock(player).expects('tell').once()
        mock.withArgs Protocol.FORFEIT_BATTLE, @battle.players.indexOf(@player1)
        mocks.push(mock)
      @battle.forfeit(@socket1)
      mock.verify()  for mock in mocks

    it "does not forfeit if the player given is invalid", ->
      mocks = []
      for player in [ @player1, @player2 ]
        mock = @sandbox.mock(player).expects('tell').never()
        mocks.push(mock)
      @battle.forfeit({})
      mock.verify()  for mock in mocks
