conditions = require '../conditions'
{_} = require 'underscore'

# Abstracts out sending messages from player to battle.
# Makes the Battle smoothly go into the next turn
# Necessary to separate out making commands and executing commands.
class @BattleController
  constructor: (@battle) ->
    conditions.attach(this)
    @battle.emit('initialize')

  # Returns the player associated with an id
  getPlayer: (playerId) ->
    @battle.getPlayer(playerId)

  # Returns all the player ids participating in this battle.
  getPlayerIds: ->
    @battle.playerIds

  # Returns all the names of players participating in this battle. 
  # These names may be masked by alts
  getPlayerNames: ->
    @battle.playerNames

  # Tells the player to execute a certain move by name. The move is added
  # to the list of player actions, which are executed once the turn continues.
  makeMove: (playerId, moveName, forSlot = 0, forTurn = @battle.turn, args...) ->
    return false  if @battle.isOver()
    return false  if forTurn != @battle.turn
    return false  if playerId not in @battle.playerIds
    pokemon = @battle.getTeam(playerId).at(forSlot)
    return false  if !pokemon
    request = @battle.requestFor(pokemon)
    return false  if !request
    return false  if moveName not in (request.moves || [])
    move = @battle.getMove(moveName)
    @battle.recordMove(playerId, move, forSlot, args...)
    @transitionToNextState()
    return true

  # Tells the player to switch with a certain pokemon specified by position.
  # The switch is added to the list of player actions, which are executed
  # once the turn continues.
  makeSwitch: (playerId, toPosition, forSlot = 0, forTurn = @battle.turn) ->
    return false  if @battle.isOver()
    return false  if forTurn != @battle.turn
    return false  if playerId not in @battle.playerIds
    pokemon = @battle.getTeam(playerId).at(forSlot)
    return false  if !pokemon
    request = @battle.requestFor(pokemon)
    return false  if !request
    return false  if toPosition not in (request.switches || [])
    @battle.recordSwitch(playerId, toPosition, forSlot)
    @transitionToNextState()
    return true

  # Tells the player to cancel their latest completed request.
  undoCompletedRequest: (playerId, forTurn = @battle.turn) ->
    return false  if forTurn != @battle.turn
    @battle.undoCompletedRequest(playerId)
    @sendUpdates()
    return true

  # Makes a player forfeit.
  forfeit: (playerId) ->
    return  if @battle.isOver()
    @battle.forfeit(playerId)
    @sendUpdates()

  addSpectator: (spectator) ->
    @battle.addSpectator(spectator)

  sendRequestTo: (spectator) ->
    @battle.sendRequestTo(spectator)

  removeSpectator: (spectator) ->
    @battle.removeSpectator(spectator)

  messageSpectators: (user, message) ->
    # Find the user in the battle just in case its masked
    # If it doesn't exist, this means its an outside user
    userInBattle = _(@battle.spectators).find((s) -> s.id == user.id)
    user = userInBattle  if userInBattle

    for spectator in @battle.spectators
      spectator.send('updateBattleChat', @battle.id, user.name, message)

  rawMessage: (message) ->
    for spectator in @battle.spectators
      spectator.send('rawBattleMessage', @battle.id, message)

  # Continue or begin a new turn if each player has made an action.
  transitionToNextState: ->
    return  if not @battle.areAllRequestsCompleted()
    if @battle.replacing
      @battle.performReplacements()
      @sendUpdates()
    else
      @continueTurn()

  # Officially starts the battle.
  beginBattle: ->
    @battle.begin()
    @sendUpdates()

  beginTurn: ->
    @battle.beginTurn()
    @sendUpdates()

  # Continues the turn. This is called once all requests
  # have been submitted and the battle is ready to continue.
  #
  # If there are no more requests, the engine progresses to endTurn. Otherwise,
  # it waits for continueTurn to be called again.
  continueTurn: ->
    @battle.continueTurn()

    # If all requests have been completed, then end the turn.
    # Otherwise, wait for further requests to be completed before ending.
    if @battle.areAllRequestsCompleted() then @endTurn()
    @sendUpdates()

  # Calls Battle#endTurn. If all pokemon are fainted, then it
  # ends the battle. Otherwise, it will request for new pokemon and wait if
  # any replacements are needed, or begins the next turn.
  endTurn: ->
    @battle.endTurn()
    @sendUpdates()

  endBattle: ->
    @battle.endBattle()
    @sendUpdates()

  # Sends battle updates to spectators.
  sendUpdates: ->
    @battle.sendUpdates()
