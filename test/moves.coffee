{Move} = require '../engine/move'

describe Move, ->
  it 'should have a priority of 0 by default', ->
    (new Move).priority.should.equal 0
