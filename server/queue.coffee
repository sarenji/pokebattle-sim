ratings = require('./ratings')
alts = require('./alts')

class QueuedPlayer
  constructor: (player) ->
    @player = player
    @range = 100
    @rating = null  # needs to be updated by getRatings

# A queue of users waiting for a battle
class @BattleQueue
  constructor: ->
    @queue = {}
    @newPlayers = []
    @recentlyMatched = {}
    @length = 0

  # Adds a player to the queue.
  # "name" can either be the real name, or an alt
  add: (playerId, name, team, ratingKey=playerId) ->
    return false  if !playerId
    return false  if playerId of @queue

    playerObject = {id: playerId, name, team, ratingKey}
    player = new QueuedPlayer(playerObject)
    @queue[playerId] = player
    @newPlayers.push(player)
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

  hasUserId: (playerId) ->
    @queue[playerId]?

  hasRecentlyMatched: (player1Id, player2Id) ->
    players = [player1Id, player2Id].sort()
    key = "#{players[0]}_#{players[1]}"
    @recentlyMatched[key]?

  addRecentMatch: (player1Id, player2Id) ->
    players = [player1Id, player2Id].sort()
    key = "#{players[0]}_#{players[1]}"
    @recentlyMatched[key] = true
    setTimeout((=> delete @recentlyMatched[key]), 30 * 60 * 1000) # expire in 30 minutes

  size: ->
    @length

  # An internal function which loads ratings for newly queued players
  # and removes them from the newly queued list
  updateNewPlayers: (next) ->
    ratingKeys = (queued.player.ratingKey for queued in @newPlayers)
    return next(null)  if ratingKeys.length == 0
    
    ratings.getRatings ratingKeys, (err, returnedRatings) =>
      if err then return next(err)

      ratings.setActive ratingKeys, (err) =>
        if err then return next(err)

        # Update the ratings in the player objects
        for rating, i in returnedRatings
          continue  unless @hasUserId(@newPlayers[i].player.id)
          @newPlayers[i].rating = rating

        @newPlayers = []  # reset the new players list, we're done
        next(null)

  # Returns an array of pairs. Each pair is a queue object that contains
  # a player and team key, corresponding to the player socket and player's team.
  pairPlayers: (next) ->
    return next(null, [])  if @size() == 0

    @updateNewPlayers (err) =>
      if err then return next(err, null)
      
      sortedPlayers = (queued for id, queued of @queue)
      sortedPlayers.sort((a, b) -> a.rating - b.rating)

      alreadyMatched = (false for [0...sortedPlayers.length])

      pairs = []
      for leftIdx in [0...sortedPlayers.length]
        continue  if alreadyMatched[leftIdx]

        for rightIdx in [(leftIdx + 1)...sortedPlayers.length]
          continue  if alreadyMatched[rightIdx]

          leftPlayer = sortedPlayers[leftIdx].player
          rightPlayer = sortedPlayers[rightIdx].player

          continue  if @hasRecentlyMatched(leftPlayer.id, rightPlayer.id)

          # TODO: START CHECKING RATING DIFF. IF ITS TOO GREAT, BREAK OUT

          # Everything checks out, so make the pair and break out
          pairs.push([leftPlayer, rightPlayer])
          @remove([leftPlayer.id, rightPlayer.id])
          @addRecentMatch(leftPlayer.id, rightPlayer.id)
          alreadyMatched[leftIdx] = alreadyMatched[rightIdx] = true
          break

      # Return the list of paired players
      next(null, pairs)
