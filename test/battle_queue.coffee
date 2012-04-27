{BattleServer} = require '../server'
{BattleQueue} = require '../server/queue'

describe 'BattleQueue', ->
  it 'should be empty by default', ->
    new BattleQueue().queue.should.be.empty

  it 'can queue a new player', ->
    queue = new BattleQueue()
    queue.queuePlayer({})
    queue.queue.should.have.length 1

  it 'can dequeue old players', ->
    queue = new BattleQueue()
    player1 = {}
    player2 = {}
    queue.queuePlayer(player1)
    queue.queuePlayer(player2)
    queue.dequeuePlayer(player1)
    queue.queue.should.have.length 1

  it 'can pair people to take them out of the queue', ->
    queue = new BattleQueue()
    queue.queuePlayer({})
    queue.queuePlayer({})
    queue.pairPlayers()
    queue.queue.should.be.empty

  it 'leaves one person out if the queue length is odd', ->
    queue = new BattleQueue()
    queue.queuePlayer({})
    queue.queuePlayer({})
    queue.queuePlayer({})
    queue.pairPlayers()
    queue.queue.should.have.length 1

  it 'can create a new battle for each pair', ->
    server = new BattleServer()
    queue = new BattleQueue(server)
    queue.queuePlayer({})
    queue.queuePlayer({})
    queue.queuePlayer({})
    queue.queuePlayer({})
    queue.pairPlayers()
    server.battles.should.have.length 2
