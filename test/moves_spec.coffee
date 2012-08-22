{Move, Pokemon} = require('../').server

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
