class @BattleQueue
  constructor: (@server) ->
    @queue = []

  queuePlayer: (player) ->
    @queue.push(player)

  # Starts battles between every pair of players
  pairPlayers: ->
    while @queue.length >= 2
      # Todo: Use something more efficient than shift
      player1 = @queue.shift()
      player2 = @queue.shift()
      @server?.startBattle(player1, player2)
