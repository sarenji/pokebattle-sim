ratings = require('./ratings')
require 'sugar'

# A queue of users waiting for a battle
class @BattleQueue
  constructor: ->
    @queue = {}
    @length = 0

  add: (playerId, team) ->
    return false  if !playerId
    return false  if playerId of @queue
    @queue[playerId] = team
    @length += 1
    return true

  remove: (playerIds) ->
    playerIds = Array(playerIds)  if playerIds not instanceof Array
    for playerId in playerIds
      if playerId of @queue
        delete @queue[playerId]
        @length -= 1

  queuedPlayers: ->
    Object.keys(@queue)

  size: ->
    @length

  # Returns an array of pairs. Each pair is a queue object that contains
  # a player and team key, corresponding to the player socket and player's team.
  pairPlayers: (next) ->
    ids = @queuedPlayers()
    return next(null, [])  if ids.length == 0
    ratings.getRatings ids, (err, ratings) =>
      if err then return next(err, null)

      pairs = []
      sortedPlayers = []

      # Get the list of players sorted by rating
      for rating, i in ratings
        id = ids[i]
        sortedPlayers.push([ {playerId: id, team: @queue[id]}, rating ])
      sortedPlayers.sort((a, b) -> a[1] - b[1])
      sortedPlayers = sortedPlayers.map((array) -> array[0])

      # Populate pair array
      for i in [0...sortedPlayers.length] by 2
        first = sortedPlayers[i]
        second = sortedPlayers[i + 1]
        continue  unless first && second
        pair = {}
        pair[first.playerId] = first.team
        pair[second.playerId] = second.team
        pairs.push(pair)

        # Remove paired players from the queue
        @remove(Object.keys(pair))

      # Return the list of paired players
      next(null, pairs)
