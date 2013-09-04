# Abstracts out sending messages from player to battle.
# Makes the Battle smoothly go into the next turn
# Necessary to separate out making commands and executing commands.
class @BattleController
  constructor: (@battle) ->

  # Tells the player to execute a certain move by name. The move is added
  # to the list of player actions, which are executed once the turn continues.
  makeMove: (player, moveName, options = {}) ->
    return  if @battle.isOver()
    pokemonMoves = @battle.getTeam(player.id).at(0).moves.map((m) -> m.name)
    return  if moveName not in pokemonMoves && !options.force
    move = @battle.getMove(moveName)
    @battle.recordMove(player.id, move)
    @transitionToNextState()

  # Tells the player to switch with a certain pokemon specified by position.
  # The switch is added to the list of player actions, which are executed
  # once the turn continues.
  makeSwitch: (player, toPosition) ->
    return  if @battle.isOver()
    return  if toPosition < @battle.numActive
    return  if toPosition >= @battle.getTeam(player.id).pokemon.length
    @battle.recordSwitch(player.id, toPosition)
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
        @battle.performReplacements()
        @beginTurn()
      else
        @continueTurn()

  # Officially starts the battle.
  beginBattle: ->
    for you, i in @battle.players
      opponents = (p  for p in @battle.players when you.id != p.id)
      # TODO: Conceal opponent teams!
      teams = @battle.players.map((p) -> p.team.toJSON())
      you.send? 'start battle', @battle.id, @battle.numActive, i, teams
    @beginTurn()

    pokemon = @battle.getActivePokemon()
    for p in pokemon
      p.switchIn(@battle)

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
