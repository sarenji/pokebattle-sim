sinon = require 'sinon'
{items} = require('../data/bw')
{Battle, Pokemon, Status} = require('../').server
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
    sinon.stub(@battle.rng, 'next', -> 1)     # no chs
    sinon.stub(@battle.rng, 'randInt', -> 0)  # always do max damage
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
      @battle.endTurn()
      defender.currentHP.should.be.equal originalHP

  describe 'fainting', ->
    it 'forces a new pokemon to be picked', ->
      create.call this,
        team1: [Factory('Mew')]
        team2: [Factory('Hitmonchan')]
      @team2.at(0).currentHP = 1
      spy = sinon.spy(@player2, 'emit')
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      spy.calledWith('request action').should.be.true

    it 'does not increment the turn count', ->
      create.call this,
        team1: [Factory('Mew')]
        team2: [Factory('Hitmonchan')]
      turn = @battle.turn
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      @battle.turn.should.not.equal turn + 1

    it 'removes the fainted pokemon from the action priority queue', ->
      create.call this,
        team1: [Factory('Mew')]
        team2: [Factory('Hitmonchan')]
      turn = @battle.turn
      @team1.at(0).currentHP = 1
      @team2.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      @team1.at(0).currentHP.should.be.below 1
      @team2.at(0).currentHP.should.equal 1

    it 'lets the player switch in a new pokemon', ->
      create.call this,
        team1: [Factory('Mew')]
        team2: [Factory('Hitmonchan'), Factory('Mew')]
      turn = @battle.turn
      pkmn = @team2.at(0)
      pkmn.currentHP = 1
      @battle.makeMove(@player1, 'Psychic')
      @battle.makeMove(@player2, 'Mach Punch')
      @battle.makeSwitch(@player2, 'Mew')
      @team2.at(0).should.not.equal pkmn

  describe 'secondary effect attacks', ->
    it 'can inflict effect on successful hit', ->
      create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Porygon-Z')]
      @battle.rng.next.restore()
      sinon.stub(@battle.rng, 'next', -> 0)     # 100% chance
      defender = @team2.at(0)
      @battle.makeMove(@player1, 'flamethrower')
      @battle.endTurn()
      defender.hasStatus(Status.BURN).should.be.true

  describe 'a pokemon with technician', ->
    it "doesn't increase damage if the move has bp > 60", ->
      create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @battle.makeMove(@player1, 'Ice Punch')
      hp = @team2.at(0).currentHP
      @battle.endTurn()
      (hp - @team2.at(0).currentHP).should.equal 84

    it "increases damage if the move has bp <= 60", ->
      create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Shaymin (land)')]
      @battle.makeMove(@player1, 'Bullet Punch')
      hp = @team2.at(0).currentHP
      @battle.endTurn()
      (hp - @team2.at(0).currentHP).should.equal 67

  describe 'STAB', ->
    it "gets applied if the move and user share a type", ->
      create.call this,
        team1: [Factory('Heracross')]
        team2: [Factory('Regirock')]
      @battle.makeMove(@player1, 'Megahorn')
      hp = @team2.at(0).currentHP
      @battle.endTurn()
      (hp - @team2.at(0).currentHP).should.equal 123

    it "doesn't get applied if the move and user are of different types", ->
      create.call this,
        team1: [Factory('Hitmonchan')]
        team2: [Factory('Mew')]
      @battle.makeMove(@player1, 'Ice Punch')
      hp = @team2.at(0).currentHP
      @battle.endTurn()
      (hp - @team2.at(0).currentHP).should.equal 84

    it 'is 2x if the pokemon has Adaptability', ->
      create.call this,
        team1: [Factory('Porygon-Z')]
        team2: [Factory('Mew')]
      @battle.makeMove(@player1, 'Tri Attack')
      hp = @team2.at(0).currentHP
      @battle.endTurn()
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
