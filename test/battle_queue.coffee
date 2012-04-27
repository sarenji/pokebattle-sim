{BattleQueue} = require '../server/queue'

describe 'BattleQueue', ->
  it 'should be empty by default', ->
    new BattleQueue().queue.should.be.empty

  describe '#add', ->
    it 'queues a new player', ->
      queue = new BattleQueue()
      queue.add({})
      queue.queue.should.have.length 1

  describe '#queuedPlayers', ->
    it 'returns the players who are queued', ->
      queue = new BattleQueue()
      dude = {}
      queue.add(dude)
      queue.queuedPlayers().should.include dude
      queue.queuedPlayers().should.have.length 1

  describe '#pairPlayers', ->
    it 'takes players out of the queue', ->
      queue = new BattleQueue()
      queue.add({})
      queue.add({})
      queue.pairPlayers()
      queue.queue.should.be.empty

    it 'leaves one person out if the queue length is odd', ->
      queue = new BattleQueue()
      queue.add({})
      queue.add({})
      queue.add({})
      queue.pairPlayers()
      queue.queue.should.have.length 1

    it 'returns an array of pairs', ->
      queue = new BattleQueue()
      queue.add({})
      queue.add({})
      queue.add({})
      queue.add({})
      pairs = queue.pairPlayers()
      pairs.should.have.length 2
