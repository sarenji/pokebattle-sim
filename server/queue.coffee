ratings = require('./ratings')
require 'sugar'

# A queue of users waiting for a battle
class @BattleQueue
  constructor: ->
    @queue = []

  add: (player, team) ->
    return false  if !player?.id?
    return false  if @queue.some((o) -> o.player.id == player.id)
    @queue.push({player, team})
    return true

  remove: (players) ->
    players = Array(players)
    queuedPlayers = @queuedPlayers()
    for player in players
      for qPlayer, i in queuedPlayers
        if player == qPlayer
          @queue.splice(index, 1)
          break

  queuedPlayers: ->
    @queue.map((o) -> o.player)

  queuedIds: ->
    @queue.map((o) -> o.player.id)

  size: ->
    @queue.length

  # Returns an array of pairs. Each pair is a queue object that contains
  # a player and team key, corresponding to the player socket and player's team.
  pairPlayers: (next) ->
    ids = @queuedIds()
    return next(null, [])  if ids.length == 0
    ratings.getRatings ids, (err, ratings) =>
      if err then return next(err, null)

      pairs = []
      sortedPlayers = []

      # Get the list of players sorted by rating
      for rating, i in ratings
        sortedPlayers.push([ @queue[i], rating ])
      sortedPlayers.sort((a, b) -> a[1] - b[1])
      sortedPlayers = sortedPlayers.map((pair) -> pair[0])

      # Populate pair array
      for i in [0...sortedPlayers.length] by 2
        first = sortedPlayers[i]
        second = sortedPlayers[i + 1]
        pairs.push([ first, second ])  if first && second

      # Remove paired players from the queue
      @queue.splice(0, pairs.length * 2)

      # Return the list of paired players
      next(null, pairs)
