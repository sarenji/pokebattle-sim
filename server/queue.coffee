# A queue of users waiting for a battle
class @BattleQueue
  constructor: ->
    @queue = []

  add: (player, team) ->
    # TODO: Do not queue players that are already in the queue
    @queue.push({player, team})

  remove: (player) ->
    players = @queue.map (object) -> object.player
    index = players.indexOf(player)
    @queue.splice(index, 1)  if index != -1

  queuedPlayers: ->
    cloned = []
    for object in @queue
      cloned.push(object.player)
    cloned

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
