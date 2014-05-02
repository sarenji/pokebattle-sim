ratings = require('./ratings')
alts = require('./alts')
require 'sugar'

# A queue of users waiting for a battle
class @BattleQueue
  constructor: ->
    @queue = {}
    @length = 0

  # Adds a player to the queue.
  # "name" can either be the real name, or an alt
  add: (playerId, name, team, ratingKey=playerId) ->
    return false  if !playerId
    return false  if playerId of @queue
    @queue[playerId] = {id: playerId, name, team, ratingKey}
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
    queueByRatingKey = {}  # a duplicate of the queued object to map back from altered ratingKeys -> objects
    queueByRatingKey[player.ratingKey] = player  for id, player of @queue
    ratingKeys = Object.keys(queueByRatingKey)

    return next(null, [])  if ratingKeys.length == 0
    ratings.getRatings ratingKeys, (err, returnedRatings) =>
      if err then return next(err, null)

      ratings.setActive ratingKeys, (err) =>
        if err then return next(err, null)
        pairs = []
        sortedPlayers = []

        # Get the list of players sorted by rating
        for rating, i in returnedRatings
          player = queueByRatingKey[ratingKeys[i]]
          sortedPlayers.push([ player, rating ])
        sortedPlayers.sort((a, b) -> a[1] - b[1])
        sortedPlayers = sortedPlayers.map((array) -> array[0])

        # Populate pair array
        for i in [0...sortedPlayers.length] by 2
          first = sortedPlayers[i]
          second = sortedPlayers[i + 1]
          continue  unless first && second
          pairs.push([first, second])

          # Remove paired players from the queue
          @remove([first.id, second.id])

        # Return the list of paired players
        next(null, pairs)
