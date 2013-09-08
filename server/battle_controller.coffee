{Conditions} = require './conditions'

# Abstracts out sending messages from player to battle.
# Makes the Battle smoothly go into the next turn
# Necessary to separate out making commands and executing commands.
class @BattleController
  constructor: (@battle) ->
    @arranged = []

  # Tells the player to execute a certain move by name. The move is added
  # to the list of player actions, which are executed once the turn continues.
  makeMove: (player, moveName, forSlot = 0) ->
    return  if @battle.isOver()
    pokemon = @battle.getTeam(player.id).at(forSlot)
    return  if !pokemon
    request = @battle.requestFor(pokemon)
    return  if !request
    return  if moveName not in (request.moves || [])
    move = @battle.getMove(moveName)
    @battle.recordMove(player.id, move, forSlot)
    @transitionToNextState()

  # Tells the player to switch with a certain pokemon specified by position.
  # The switch is added to the list of player actions, which are executed
  # once the turn continues.
  makeSwitch: (player, toPosition, forSlot = 0) ->
    return  if @battle.isOver()
    pokemon = @battle.getTeam(player.id).at(forSlot)
    return  if !pokemon
    request = @battle.requestFor(pokemon)
    return  if !request
    return  if toPosition not in (request.switches || [])
    @battle.recordSwitch(player.id, toPosition, forSlot)
    @transitionToNextState()

  # Makes a player forfeit.
  forfeit: (player) ->
    return  if @battle.isOver()
    @battle.forfeit(player)
    @sendUpdates()

  addSpectator: (spectator) ->
    @battle.addSpectator(spectator)

  # Continue or begin a new turn if each player has made an action.
  transitionToNextState: ->
    if @battle.areAllRequestsCompleted()
      if @battle.replacing
        @beginTurn()
      else
        @continueTurn()

  # Officially starts the battle.
  beginBattle: ->
    for you, i in @battle.players
      opponents = (p  for p in @battle.players when you.id != p.id)
      # TODO: Conceal opponent teams!
      teams = @battle.players.map((p) -> p.team.toJSON())
      you.send? 'initialize battle', @battle.id, @battle.numActive, you.index

    # Team Preview asks for order before starting the battle.
    if @battle.hasCondition(Conditions.TEAM_PREVIEW)
      teams = @battle.players.map((p) -> p.team.toJSON(hidden: true))
      for you, i in @battle.players
        you.send? 'team preview', @battle.id, teams
    else
      @_beginBattle()

  arrangeTeam: (player, arrangement) ->
    return false  if arrangement not instanceof Array
    team = @battle.getTeam(player.id)
    return false  if arrangement.length != team.size()
    for index, i in arrangement
      return false  if isNaN(index)
      return false  if !team.pokemon[index]
      return false  if arrangement.indexOf(index, i + 1) != -1

    team.arrange(arrangement)
    @arranged.push(player.id)
    @_beginBattle()  if @battle.players.all((player) => player.id in @arranged)
    return true

  _beginBattle: ->
    @battle.begin()
    @beginTurn()

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

    if @battle.areReplacementsNeeded()
      if !@battle.isOver()
        @battle.requestFaintedReplacements()
      else
        @endBattle()
    else
      @beginTurn()
    @sendUpdates()

  endBattle: ->
    @battle.endBattle()

  # Sends battle updates to players.
  sendUpdates: ->
    for player in @battle.players
      continue  if player.queue.length == 0
      player.send('update battle', @battle.id, player.queue)
      player.queue = []
    for spectator in @battle.spectators
      continue  if spectator.queue.length == 0
      spectator.send('update battle', @battle.id, spectator.queue)
      spectator.queue = []
