sinon = require 'sinon'
{Battle, Pokemon, Weather} = require('../').server
{Factory} = require('./factory')
{moves} = require('../data/bw')

describe 'Battle', ->
  beforeEach ->
    @player1 = {id: 'abcde'}
    @player2 = {id: 'fghij'}
    team1   = [Factory('Hitmonchan'), Factory('Heracross')]
    team2   = [Factory('Hitmonchan'), Factory('Heracross')]
    players = [{player: @player1, team: team1},
               {player: @player2, team: team2}]
    @battle = new Battle('id', players: players)
    @team1  = @battle.getTeam(@player1.id)
    @team2  = @battle.getTeam(@player2.id)

  it 'starts at turn 1', ->
    @battle.turn.should.equal 1

  describe '#hasWeather(weatherName)', ->
    it 'returns true if the current battle weather is weatherName', ->
      @battle.weather = "Sunny"
      @battle.hasWeather("Sunny").should.be.true

    it 'returns false on non-None in presence of a weather-cancel ability', ->
      @battle.weather = "Sunny"
      sinon.stub(@battle, 'hasWeatherCancelAbilityOnField', -> true)
      @battle.hasWeather("Sunny").should.be.false

    it 'returns true on None in presence of a weather-cancel ability', ->
      @battle.weather = "Sunny"
      sinon.stub(@battle, 'hasWeatherCancelAbilityOnField', -> true)
      @battle.hasWeather("None").should.be.true

  describe '#makeMove', ->
    it "records a player's move", ->
      @battle.makeMove(@player1, 'Tackle')
      @battle.playerActions.should.have.property @player1.id
      @battle.playerActions[@player1.id].move.name.should.equal 'tackle'

    # TODO: Invalid moves should fail in some way.
    it "doesn't record invalid moves", ->
      @battle.makeMove(@player1, 'Blooberry Gun')
      @battle.playerActions.should.not.have.property @player1.id

    it "automatically ends the turn if all players move", ->
      mock = sinon.mock(@battle)
      mock.expects('continueTurn').once()
      @battle.makeMove(@player1, 'Tackle')
      @battle.makeMove(@player2, 'Tackle')
      mock.verify()

  describe '#makeSwitch', ->
    it "swaps pokemon positions of a player's team", ->
      [poke1, poke2] = @team1.pokemon
      @battle.makeSwitch(@player1, 1)
      @battle.makeMove(@player2, "Splash")
      @team1.pokemon.slice(0, 2).should.eql [poke2, poke1]

    it "automatically ends the turn if all players switch", ->
      mock = sinon.mock(@battle)
      mock.expects('continueTurn').once()
      @battle.makeSwitch(@player1, 1)
      @battle.makeSwitch(@player2, 1)
      mock.verify()

    it "calls the pokemon's switchOut() method", ->
      pokemon = @team1.first()
      mock = sinon.mock(pokemon)
      mock.expects('switchOut').once()
      @battle.makeSwitch(@player1, 1)
      @battle.makeMove(@player2, "Splash")
      mock.verify()

  describe "#setWeather", ->
    it "can last a set number of turns", ->
      @battle.setWeather(Weather.SUN, 5)
      for i in [0...5]
        @battle.makeMove(@player1, "Splash")
        @battle.makeMove(@player2, "Splash")
      @battle.weather.should.equal Weather.NONE

  describe "weather", ->
    it "damages pokemon who are not of a certain type", ->
      @battle.setWeather(Weather.SAND)
      @battle.makeMove(@player1, "Splash")
      @battle.makeMove(@player2, "Splash")
      maxHP = @team1.first().stat('hp')
      (maxHP - @team1.first().currentHP).should.equal Math.floor(maxHP / 16)
      (maxHP - @team2.first().currentHP).should.equal Math.floor(maxHP / 16)

      @battle.setWeather(Weather.HAIL)
      @battle.makeMove(@player1, "Splash")
      @battle.makeMove(@player2, "Splash")
      maxHP = @team1.first().stat('hp')
      (maxHP - @team1.first().currentHP).should.equal 2*Math.floor(maxHP / 16)
      (maxHP - @team2.first().currentHP).should.equal 2*Math.floor(maxHP / 16)

  describe "move PP", ->
    it "goes down after a pokemon uses a move", ->
      p1 = @team1.first()
      p2 = @team2.first()
      p1Move = p1.moves[0]
      p2Move = p2.moves[1]
      @battle.makeMove(@player1, p1Move.name)
      @battle.makeMove(@player2, p2Move.name)

      p1.pp(p1Move).should.equal p1.maxPP(p1Move) - 1
      p2.pp(p2Move).should.equal p2.maxPP(p2Move) - 1
