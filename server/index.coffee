{BattleQueue} = require './queue'

class @BattleServer
  constructor: (@engine) ->
    @queue = new BattleQueue(this)

  queuePlayer: (player) =>
    @queue.add(player)

  queuedPlayers: =>
    @queue.queuedPlayers()

  beginBattles: =>
    pairs = @queue.pairPlayers()

    # Create a battle for each pair
    for pair in pairs
      id = @engine.createBattle(pair...)

      # Tell each player to start a battle with an id `id`.
      for player in pair
        player.emit? 'start battle', id
