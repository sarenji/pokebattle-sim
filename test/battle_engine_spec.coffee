sinon = require 'sinon'
{items} = require('../data/bw')
{Battle, Pokemon} = require('../').server

describe 'Mechanics', ->
  create = (opts={}) ->
    @id1 = 'abcde'
    @id2 = 'fghij'
    @player1 = opts.player1 || {id: @id1}
    @player2 = opts.player2 || {id: @id2}
    team1   = opts.team1 || [{}, {}]
    team2   = opts.team2 || [{}, {}]
    players = [{player: @player1, team: team1},
               {player: @player2, team: team2}]
    @battle = new Battle(players: players)
    sinon.stub(@battle.rng, 'next', -> 1)     # no chs
    sinon.stub(@battle.rng, 'randInt', -> 0)  # always do max damage
    @team1  = @battle.getTeam(@player1.id)
    @team2  = @battle.getTeam(@player2.id)

  describe 'splash', ->
    it 'does no damage', ->
      create.call(this)
      defender = @team2[0]
      originalHP = defender.currentHP
      @battle.makeMove(@player1, 'splash')
      @battle.endTurn()
      defender.currentHP.should.be.equal originalHP

  describe 'secondary effect attacks', ->
    it 'can inflict effect on successful hit', ->
      create.call(this)
      @battle.rng.next.restore()
      sinon.stub(@battle.rng, 'next', -> 0)     # 100% chance
      defender = @team2[0]
      @battle.makeMove(@player1, 'flamethrower')
      @battle.endTurn()
      defender.hasStatus('burn').should.be.true

  describe 'a pokemon with technician', ->
    it "doesn't increase damage if the move has bp > 60", ->
      create.call this,
        team1: [{
          name: 'Hitmonchan'
          ability: 'Technician'
          moves: ['Ice Punch']
          evs: {attack: 252}
        }]
        team2: [{name: 'Mew'}]
      @battle.makeMove(@player1, 'Ice Punch')
      hp = @team2[0].currentHP
      @battle.endTurn()
      (hp - @team2[0].currentHP).should.equal 84

    it "increases damage if the move has bp <= 60", ->
      create.call this,
        team1: [{
          name: 'Hitmonchan'
          ability: 'Technician'
          moves: ['Bullet Punch']
          evs: {attack: 252}
        }]
        team2: [{name: 'Shaymin'}]
      @battle.makeMove(@player1, 'Bullet Punch')
      hp = @team2[0].currentHP
      @battle.endTurn()
      (hp - @team2[0].currentHP).should.equal 67

  describe 'STAB', ->
    it "gets applied if the move and user share a type", ->
      create.call this,
        team1: [{
          name: 'Heracross'
          ability: 'Guts'
          moves: ['Megahorn']
          evs: {attack: 252}
        }]
        team2: [{
          name: 'Regirock'
        }]
      @battle.makeMove(@player1, 'Megahorn')
      hp = @team2[0].currentHP
      @battle.endTurn()
      (hp - @team2[0].currentHP).should.equal 123

    it "doesn't get applied if the move and user are of different types", ->
      create.call this,
        team1: [{
          name: 'Hitmonchan'
          ability: 'Technician'
          moves: ['Ice Punch']
          evs: {attack: 252}
        }]
        team2: [{name: 'Mew'}]
      @battle.makeMove(@player1, 'Ice Punch')
      hp = @team2[0].currentHP
      @battle.endTurn()
      (hp - @team2[0].currentHP).should.equal 84

    it 'is 2x if the pokemon has Adaptability', ->
      create.call this,
        team1: [{
          name: 'Porygon-Z'
          ability: 'Adaptability'
          moves: ['Tri Attack']
          evs: {specialAttack: 252}
        }]
        team2: [{name: 'Mew'}]
      @battle.makeMove(@player1, 'Tri Attack')
      hp = @team2[0].currentHP
      @battle.endTurn()
      (hp - @team2[0].currentHP).should.equal 214

  describe 'turn order', ->
    it 'randomly decides winner if pokemon have the same speed and priority', ->
      create.call this,
        team1: [{
          name: 'Mew'
          moves: ['Psychic']
        }]
        team2: [{
          name: 'Mew'
          moves: ['Psychic']
        }]
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
        team1: [{
          name: 'Hitmonchan'
          moves: ['Mach Punch', 'ThunderPunch']
        }]
        team2: [{
          name: 'Hitmonchan'
          moves: ['Mach Punch', 'ThunderPunch']
        }]
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
        team1: [{
          name: 'Hitmonchan'
          moves: ['Mach Punch', 'ThunderPunch']
        }]
        team2: [{
          name: 'Hitmonchan'
          moves: ['Mach Punch', 'ThunderPunch']
          evs: {speed: 4}
        }]
      spy = sinon.spy(@battle, 'orderIds')
      @battle.makeMove(@player1, 'ThunderPunch')
      @battle.makeMove(@player2, 'ThunderPunch')
      spy.returned([@id2, @id1]).should.be.true
