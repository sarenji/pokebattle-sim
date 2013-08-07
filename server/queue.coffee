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

  remove: (player) ->
    players = @queuedPlayers()
    index = players.indexOf(player)
    @queue.splice(index, 1)  if index != -1

  queuedPlayers: ->
    @queue.map((o) -> o.player)

  size: ->
    @queue.length

  # Returns an array of pairs. Each pair is a queue object that contains
  # a player and team key, corresponding to the player socket and player's team.
  pairPlayers: ->
    pairs = []

    # Take players out of the queue and add them to a pairs array.
    while @queue.length >= 2
      # Todo: Use something more efficient than shift
      object1 = @queue.shift()
      object2 = @queue.shift()

      pairs.push([ object1, object2 ])

    # Return the list of paired players
    pairs
