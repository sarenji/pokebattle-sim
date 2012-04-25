class @BattleQueue
  constructor: ->
    @queue = []

  queuePlayer: (player) ->
    @queue.push(player)

  pairPlayers: ->
    pairs = []
    for i in [1..@queue.length] by 2
      pairs.push(@queue[i - 1], @queue[i])
    pairs
