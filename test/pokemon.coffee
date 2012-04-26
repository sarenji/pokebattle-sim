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
