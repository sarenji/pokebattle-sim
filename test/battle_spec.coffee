{Battle} = require '../server/battle'

describe 'Battle', ->
  it 'starts at turn 0', ->
    new Battle().turn.should.equal 0

