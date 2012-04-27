class @BattleQueue
  constructor: (@server) ->
    @queue = []

  add: (player) ->
    @queue.push(player)

  # Starts battles between every pair of players
  queuedPlayers: ->
    cloned = []
    for player in @queue
      cloned.push(player)
    cloned

  pairPlayers: ->
    pairs = []

    # Take players out of the queue and add them to a pairs array.
    while @queue.length >= 2
      # Todo: Use something more efficient than shift
      player1 = @queue.shift()
      player2 = @queue.shift()

      pairs.push([ player1, player2 ])

    # Return the list of paired players
    pairs
