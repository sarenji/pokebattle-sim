sinon = require 'sinon'
{Battle, Move, Pokemon} = require('../').server

describe 'Move', ->
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

  describe 'STAB', ->
    it "doesn't get applied if the move and user are of different types", ->
      user = new Pokemon(types: ['Bug'])
      new Move(null, type: 'Grass').stab(user).should.equal 0x1000

    it 'gets applied if the move and user share a type', ->
      user = new Pokemon(types: ['Grass'])
      new Move(null, type: 'Grass').stab(user).should.equal 0x1800

  describe 'critical hit level', ->
    it "is 1 by default", ->
      battle = new Battle(players: [])
      attacker = new Pokemon()
      defender = new Pokemon()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 1

    it "can be changed from the default", ->
      battle = new Battle(players: [])
      attacker = new Pokemon()
      defender = new Pokemon()
      new Move(null, criticalHitLevel: 2)
        .criticalHitLevel(battle, attacker, defender).should.equal 2

    it "is 2 if the attacker has Super Luck", ->
      battle = new Battle(players: [])
      attacker = new Pokemon(ability: 'Super Luck')
      defender = new Pokemon()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 2

    it "is 3 if the attacker is Farfetch'd with a Stick", ->
      battle = new Battle(players: [])
      attacker = new Pokemon(name: "Farfetch'd", item: 'Stick')
      defender = new Pokemon()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 3

    it "is 3 if the attacker is Chansey with a Lucky Punch", ->
      battle = new Battle(players: [])
      attacker = new Pokemon(name: "Chansey", item: 'Lucky Punch')
      defender = new Pokemon()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 3

    it "is 2 if the attacker has a Razor Claw", ->
      battle = new Battle(players: [])
      attacker = new Pokemon(item: 'Razor Claw')
      defender = new Pokemon()
      new Move().criticalHitLevel(battle, attacker, defender).should.equal 2

  describe "critical hit", ->
    it "occurs when the RNG output < the critical hit level", ->
      battle = new Battle(players: [])
      attacker = new Pokemon()
      defender = new Pokemon()
      move = new Move()
      sinon.stub(move, 'criticalHitLevel', -> 3)
      sinon.stub(battle.rng, 'next', -> 0.2)
      move.isCriticalHit(battle, attacker, defender).should.be.true

    it "does not occur when the RNG output >= the critical hit level", ->
      battle = new Battle(players: [])
      attacker = new Pokemon()
      defender = new Pokemon()
      sinon.stub(battle.rng, 'next', -> 0.0700)
      new Move().isCriticalHit(battle, attacker, defender).should.be.false

    it "does not occur if the defender has Battle Armor", ->
      battle = new Battle(players: [])
      attacker = new Pokemon()
      defender = new Pokemon(ability: 'Battle Armor')
      move = new Move()
      sinon.stub(move, 'criticalHitLevel', -> 3)
      sinon.stub(battle.rng, 'next', -> 0.2)
      move.isCriticalHit(battle, attacker, defender).should.be.false

    it "does not occur if the defender has Shell Armor", ->
      battle = new Battle(players: [])
      attacker = new Pokemon()
      defender = new Pokemon(ability: 'Shell Armor')
      move = new Move()
      sinon.stub(move, 'criticalHitLevel', -> 3)
      sinon.stub(battle.rng, 'next', -> 0.2)
      move.isCriticalHit(battle, attacker, defender).should.be.false

  describe 'type effectiveness', ->
    it 'is 0 if the enemy has an immunity to the type', ->
      defender = new Pokemon(types: ['Electric', 'Flying'])
      new Move(null, type: 'Ground').typeEffectiveness(defender).should.equal 0

    it 'is 1 if the enemy is neutral to the type', ->
      defender = new Pokemon(types: ['Normal'])
      new Move(null, type: 'Ground').typeEffectiveness(defender).should.equal 1

    it 'is 2 if the enemy is weak to the type', ->
      defender = new Pokemon(types: ['Electric'])
      new Move(null, type: 'Ground').typeEffectiveness(defender).should.equal 2

    it 'is 4 if the enemy is extra weak to the type', ->
      defender = new Pokemon(types: ['Fire', 'Flying'])
      new Move(null, type: 'Rock').typeEffectiveness(defender).should.equal 4

    it 'is 1/2 if the enemy is resistant to the type', ->
      defender = new Pokemon(types: ['Fire', 'Flying'])
      new Move(null, type: 'Fire').typeEffectiveness(defender).should.equal .5

    it 'is 1/4 if the enemy is extra resistant to the type', ->
      defender = new Pokemon(types: ['Fire', 'Water'])
      new Move(null, type: 'Fire').typeEffectiveness(defender).should.equal .25
