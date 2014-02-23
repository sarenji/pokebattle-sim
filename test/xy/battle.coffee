{Attachment} = require('../../server/xy/attachment')
{Battle} = require('../../server/xy/battle')
{BattleController} = require('../../server/xy/battle_controller')
{Pokemon} = require('../../server/xy/pokemon')
{Weather} = require('../../shared/weather')
{Ability} = require('../../server/xy/data/abilities')
{Factory} = require('../factory')
{Player} = require('../../server/player')
{Protocol} = require '../../shared/protocol'
should = require 'should'
sinon = require 'sinon'
shared = require '../shared'

require '../helpers'

describe "XY Battle:", ->
  describe "mega evolution", ->
    it "gets recorded when recording a move", ->
      shared.create.call this,
        gen: 'xy'
        team1: [ Factory("Charizard", moves: ["Fire Blast"], item: "Charizardite X") ]
      @battle.pokemonActions.filter((o) -> o.type == 'mega').should.have.length(0)
      @battle.recordMove(@id1, @battle.getMove("Fire Blast"), 0, true)
      megas = @battle.pokemonActions.filter((o) -> o.type == 'mega')
      megas.should.have.length(1)
      megas[0].pokemon.should.equal(@p1)

    it "doesn't get recorded if the pokemon can't mega evolve", ->
      shared.create.call this,
        gen: 'xy'
        team1: [ Factory("Magikarp", item: "Charizardite X") ]
      @battle.pokemonActions.filter((o) -> o.type == 'mega').should.have.length(0)
      @battle.recordMove(@id1, @battle.getMove("Splash"), 0, true)
      @battle.pokemonActions.filter((o) -> o.type == 'mega').should.have.length(0)

    it "cannot happen if your partner is already going to mega-evolve", ->
      shared.create.call this,
        gen: 'xy'
        numActive: 2
        team1: (Factory("Charizard", moves: ["Fire Blast"], item: "Charizardite X")  for x in [0..1])
      @battle.pokemonActions.filter((o) -> o.type == 'mega').should.have.length(0)
      @battle.recordMove(@id1, @battle.getMove("Fire Blast"), 0, true)
      @battle.pokemonActions.filter((o) -> o.type == 'mega').should.have.length(1)
      @battle.recordMove(@id1, @battle.getMove("Fire Blast"), 1, true)
      @battle.pokemonActions.filter((o) -> o.type == 'mega').should.have.length(1)

    it "happens after switches", ->
      shared.create.call this,
        gen: 'xy'
        team1: [ Factory("Charizard", moves: ["Fire Blast"], item: "Charizardite X") ]
        team2: (Factory("Magikarp")  for x in [0..1])
      @battle.recordMove(@id1, @battle.getMove("Fire Blast"), 0, true)
      @battle.recordSwitch(@id2, 1)
      megaSpy = @sandbox.spy(@battle, 'performMegaEvolution')
      switchSpy = @sandbox.spy(@battle, 'performSwitch')
      @battle.continueTurn()
      switchSpy.calledBefore(megaSpy).should.be.true

    it "changes the pokemon's forme", ->
      shared.create.call this,
        gen: 'xy'
        team1: [ Factory("Charizard", moves: ["Fire Blast"], item: "Charizardite X") ]
        team2: (Factory("Magikarp")  for x in [0..1])
      @battle.recordMove(@id1, @battle.getMove("Fire Blast"), 0, true)
      @battle.continueTurn()
      @p1.forme.should.equal('mega-x')

    it "changes the pokemon's ability", ->
      shared.create.call this,
        gen: 'xy'
        team1: [ Factory("Kangaskhan", moves: ["Return"], item: "Kangaskhanite") ]
      @battle.recordMove(@id1, @battle.getMove("Fire Blast"), 0, true)
      @battle.continueTurn()
      should.exist(@p1.ability)
      @p1.ability.should.equal(Ability.ParentalBond)

    it "retains the changed ability upon switching back in", ->
      shared.create.call this,
        gen: 'xy'
        team1: [ Factory("Kangaskhan", moves: ["Return"], item: "Kangaskhanite"), Factory("Magikarp") ]
      @battle.recordMove(@id1, @battle.getMove("Fire Blast"), 0, true)
      @battle.continueTurn()
      should.exist(@p1.ability)
      @p1.ability.should.equal(Ability.ParentalBond)
      @battle.performSwitch(@team1.first(), 1)
      @battle.performSwitch(@team1.first(), 1)
      should.exist(@p1.ability)
      @p1.ability.should.equal(Ability.ParentalBond)

  describe "#getAction", ->
    it "does not consider mega evolutions", ->
      shared.create.call this,
        gen: 'xy'
        team1: [ Factory("Charizard", moves: ["Fire Blast"], item: "Charizardite X") ]
      @battle.recordMove(@id1, @battle.getMove("Fire Blast"), 0, true)
      @battle.getAction(@p1).type.should.equal("move")

  describe "#undoCompletedRequest", ->
    it "cancels mega evolutions properly", ->
      shared.create.call this,
        gen: 'xy'
        team1: [ Factory("Charizard", moves: ["Fire Blast"], item: "Charizardite X") ]
      @battle.recordMove(@id1, @battle.getMove("Fire Blast"), 0, true)
      @battle.pokemonActions.should.not.be.empty
      (=> @battle.undoCompletedRequest(@id1)).should.not.throw()
      @battle.pokemonActions.should.be.empty
