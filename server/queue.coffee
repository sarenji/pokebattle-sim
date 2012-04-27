class @BattleQueue
  constructor: (@server) ->
    @queue = []

  # Adds a player to the queue
  # TODO: Do not queue players that are already in the queue
  queuePlayer: (player) ->
    @queue.push(player)

  # Removes a player from the queue
  dequeuePlayer: (player) ->
    index = @queue.indexOf(player)
    @queue.splice(index, 1) if index != -1

  # Starts battles between every pair of players
  pairPlayers: ->
    while @queue.length >= 2
      # Todo: Use something more efficient than shift
      player1 = @queue.shift()
      player2 = @queue.shift()
      @server?.startBattle(player1, player2)
