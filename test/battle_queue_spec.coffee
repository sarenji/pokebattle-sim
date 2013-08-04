{BattleQueue} = require('../').server

describe 'BattleQueue', ->
  it 'should be empty by default', ->
    new BattleQueue().queue.should.be.empty

  describe '#add', ->
    it 'queues a new player', ->
      queue = new BattleQueue()
      queue.add({}, {})
      queue.queue.should.have.length 1

    it 'queues two players', ->
      queue = new BattleQueue()
      queue.add({}, {})
      queue.add({}, {})
      queue.queue.should.have.length 2

    it 'cannot queue the same player twice', ->
      queue = new BattleQueue()
      reference = {}
      queue.add(reference, {})
      queue.add(reference, {})
      queue.queue.should.have.length 1

    it 'cannot queue falsy references', ->
      queue = new BattleQueue()
      queue.add(null, {})
      queue.add(false, {})
      queue.add(undefined, {})
      queue.queue.should.have.length 0

  describe '#remove', ->
    it 'can dequeue old players', ->
      queue = new BattleQueue()
      player = {}
      queue.add(player, {})
      queue.remove(player)
      queue.queue.should.have.length 0

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
      queue.queuedPlayers().should.be.empty

    it 'leaves one person out if the queue length is odd', ->
      queue = new BattleQueue()
      queue.add({})
      queue.add({})
      queue.add({})
      queue.pairPlayers()
      queue.queuedPlayers().should.have.length 1

    it 'returns an array of pairs', ->
      queue = new BattleQueue()
      queue.add({})
      queue.add({})
      queue.add({})
      queue.add({})
      pairs = queue.pairPlayers()
      pairs.should.have.length 2
