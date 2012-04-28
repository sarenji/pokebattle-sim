{Pokemon} = require '../engine/pokemon'

describe 'Pokemon', ->
  it 'should have a name of Missingno by default', ->
    new Pokemon().name.should.equal 'Missingno'

  it 'can change the default name', ->
    new Pokemon(name: 'Pikachu').name.should.equal 'Pikachu'

  it 'should have a level of 100 by default', ->
    new Pokemon().level.should.equal 100

  it 'can change the default level', ->
    new Pokemon(level: 5).level.should.equal 5

  it 'makes aliases for stat', ->
    pokemon = new Pokemon(level: 100)
    pokemon.stat('hp').should.equal(pokemon.hp())

  describe '#iv', ->
    it 'has default iv', ->
      new Pokemon().iv('hp').should.equal 31
    it 'retrieves iv successfully', ->
      new Pokemon(ivs: {'hp': 25}).iv('hp').should.equal 25

  describe '#ev', ->
    it 'has default ev', ->
      new Pokemon().ev('hp').should.equal 0

    it 'retrieves ev successfully', ->
      new Pokemon(evs: {'hp': 25}).ev('hp').should.equal 25

  describe '#stat', ->
    it 'calculates hp correctly', ->
      pokemon = new Pokemon(level: 100, evs: { hp: 255 })
      pokemon.stat('hp').should.equal 404
      # todo: test other numbers later

    it 'calculates other stats correctly', ->
      pokemon = new Pokemon(level: 100, evs: { atk: 255 })
      pokemon.stat('atk').should.equal 299
      # todo: test other numbers later
