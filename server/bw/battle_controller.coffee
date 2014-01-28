{Conditions} = require '../conditions'

# Abstracts out sending messages from player to battle.
# Makes the Battle smoothly go into the next turn
# Necessary to separate out making commands and executing commands.
class @BattleController
  constructor: (@battle) ->
    @arranged = []
    @arranging = false

  # Tells the player to execute a certain move by name. The move is added
  # to the list of player actions, which are executed once the turn continues.
  makeMove: (playerId, moveName, forSlot = 0, forTurn = @battle.turn, args...) ->
    return  if @battle.isOver()
    return  if forTurn != @battle.turn
    pokemon = @battle.getTeam(playerId).at(forSlot)
    return  if !pokemon
    request = @battle.requestFor(pokemon)
    return  if !request
    return  if moveName not in (request.moves || [])
    move = @battle.getMove(moveName)
    @battle.recordMove(playerId, move, forSlot, args...)
    @transitionToNextState()

  # Tells the player to switch with a certain pokemon specified by position.
  # The switch is added to the list of player actions, which are executed
  # once the turn continues.
  makeSwitch: (playerId, toPosition, forSlot = 0, forTurn = @battle.turn) ->
    return  if @battle.isOver()
    return  if forTurn != @battle.turn
    pokemon = @battle.getTeam(playerId).at(forSlot)
    return  if !pokemon
    request = @battle.requestFor(pokemon)
    return  if !request
    return  if toPosition not in (request.switches || [])
    @battle.recordSwitch(playerId, toPosition, forSlot)
    @transitionToNextState()

  # Tells the player to cancel their latest completed request.
  undoCompletedRequest: (playerId, forTurn = @battle.turn) ->
    return  if forTurn != @battle.turn
    @battle.undoCompletedRequest(playerId)
    @sendUpdates()

  # Makes a player forfeit.
  forfeit: (playerId) ->
    return  if @battle.isOver()
    @battle.forfeit(playerId)
    @sendUpdates()

  addSpectator: (spectator) ->
    isNew = @battle.addSpectator(spectator)
    if @arranging && isNew
      teams = @battle.getTeams().map((t) -> t.toJSON(hidden: true))
      spectator.send? 'team preview', @battle.id, teams

  sendRequestTo: (spectator) ->
    @battle.sendRequestTo(spectator)

  removeSpectator: (spectator) ->
    @battle.removeSpectator(spectator)

  messageSpectators: (user, message) ->
    for spectator in @battle.spectators
      spectator.send('update battle chat', @battle.id, user.id, message)

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
    # Team Preview asks for order before starting the battle.
    if @battle.hasCondition(Conditions.TEAM_PREVIEW)
      @arranging = true
      teams = @battle.getTeams().map((t) -> t.toJSON(hidden: true))
      for you, i in @battle.spectators
        you.send? 'team preview', @battle.id, teams
    else
      @_beginBattle()

  arrangeTeam: (playerId, arrangement) ->
    return false  if @battle.hasStarted()
    return false  if arrangement not instanceof Array
    team = @battle.getTeam(playerId)
    return false  if !team
    return false  if arrangement.length != team.size()
    for index, i in arrangement
      return false  if isNaN(index)
      return false  if !team.pokemon[index]
      return false  if arrangement.indexOf(index, i + 1) != -1

    team.arrange(arrangement)
    @arranged.push(playerId)
    @_beginBattle()  if @battle.playerIds.all((id) => id in @arranged)
    return true

  _beginBattle: ->
    @arranging = false
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
