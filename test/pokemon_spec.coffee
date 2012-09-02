{Pokemon} = require('../').server

describe 'Pokemon', ->
  it 'should have a name of Missingno by default', ->
    new Pokemon().name.should.equal 'Missingno'

  it 'can change the default name', ->
    new Pokemon(name: 'Pikachu').name.should.equal 'Pikachu'

  it 'should have a level of 100 by default', ->
    new Pokemon().level.should.equal 100

  it 'can change the default level', ->
    new Pokemon(level: 5).level.should.equal 5

  it 'gets its current hp populated from its max hp', ->
    new Pokemon().currentHP.should.equal 341

  describe '#iv', ->
    it 'has default iv of 31', ->
      new Pokemon().iv('hp').should.equal 31

    it 'retrieves iv successfully', ->
      new Pokemon(ivs: {'hp': 25}).iv('hp').should.equal 25

    it "doesn't default to 31 if iv is 0", ->
      new Pokemon(ivs: {'hp': 0}).iv('hp').should.equal 0

  describe '#ev', ->
    it 'has default ev of 0', ->
      new Pokemon().ev('hp').should.equal 0

    it 'retrieves ev successfully', ->
      new Pokemon(evs: {hp: 25}).ev('hp').should.equal 25

  describe '#stat', ->
    it 'calculates hp correctly', ->
      pokemon = new Pokemon(level: 100, evs: { hp: 255 })
      pokemon.stat('hp').should.equal 404
      pokemon = new Pokemon(level: 50, evs: { hp: 255 })
      pokemon.stat('hp').should.equal 207
      # todo: test other numbers later

    it 'calculates other stats correctly', ->
      pokemon = new Pokemon(level: 100, evs: { attack: 255 })
      pokemon.stat('attack').should.equal 299
      pokemon = new Pokemon(level: 50, evs: { attack: 255 })
      pokemon.stat('attack').should.equal 152
      # todo: test other numbers later

    it "calculates a stat with a nature boost correctly", ->
      pokemon = new Pokemon(nature: 'Adamant')
      pokemon.stat('attack').should.equal 259

    it "calculates a stat with a nature decrease correctly", ->
      pokemon = new Pokemon(nature: 'Bold')
      pokemon.stat('attack').should.equal 212

  describe 'stat boosts', ->
    it 'increase the stat by (n+2)/2 if positive', ->
      pokemon = new Pokemon()
      speed = pokemon.stat('speed')
      pokemon.stages.speed = 3
      pokemon.stat('speed').should.equal Math.floor(2.5 * speed)

    it 'decrease the stat by 2/(n+2) if negative', ->
      pokemon = new Pokemon()
      speed = pokemon.stat('speed')
      pokemon.stages.speed = -3
      pokemon.stat('speed').should.equal Math.floor(speed / 2.5)

  describe '#natureBoost', ->
    it "returns 1 by default for non-existent natures", ->
      new Pokemon(nature: 'Super').natureBoost('attack').should.equal 1

    it "returns 1.1 for natures that boost a certain stat", ->
      new Pokemon(nature: 'Adamant').natureBoost('attack').should.equal 1.1

    it "returns 1.0 for natures do not affect a certain stat", ->
      new Pokemon(nature: 'Adamant').natureBoost('speed').should.equal 1

    it "returns 0.9 for natures that decrease a certain stat", ->
      new Pokemon(nature: 'Timid').natureBoost('attack').should.equal 0.9

  describe '#hasType', ->
    it 'returns false if the pokemon does not have that type', ->
      new Pokemon().hasType('Grass').should.be.false

    it 'returns true if the pokemon has that type', ->
      new Pokemon(types: ['Dark', 'Grass']).hasType('Grass').should.be.true
