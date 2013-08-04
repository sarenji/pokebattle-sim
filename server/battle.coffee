{_} = require 'underscore'
{FakeRNG} = require './rng'
{Pokemon} = require './pokemon'
{Player} = require './player'
{Team} = require './team'
{Weather} = require './weather'
{Attachment, Attachments} = require './attachment'

require 'sugar'

class @Battle
  # TODO: let Battle serialize these.
  {Ability, Moves, MoveData, MoveList, Species, PokemonData} = require '../data/bw'

  constructor: (@id, attributes = {}) ->
    # Number of pokemon on each side of the field
    @numActive = attributes.numActive || 1

    # Stores the current turn of the battle
    @turn = 0

    # Stores the actions each player is about to make
    # Keyed by player.id
    @playerActions = {}

    # Stores the current requests for moves. Keyed by player.id
    @requests = {}

    # Stores queue of players that need to move.
    @requestQueue = []

    # Creates a RNG for this battle.
    @rng = new FakeRNG()

    # Maps clientId -> object
    @objectHash = {}

    # Current battle weather.
    @weather = Weather.NONE

    # Current turn duration for the weather. -1 means infinity.
    @weatherDuration = -1

    # Buffer of messages to send to each client.
    @buffer = []

    # Array of players partaking in the battle.
    @players = []

    # Stores last move used
    @lastMove = null

    # Stores last pokemon that moved
    @lastPokemon = null

    # A queue of Pokemon ordered by priority of their moves.
    @priorityQueue = null

    # Stores the confusion recoil move as it may be different cross-generations
    @confusionMove = Moves['Confusion Recoil']

    # Stores attachments on the battle itself.
    @attachments = new Attachments()

    for object, i in attributes.players
      {player, team} = object
      player = new Player(player)
      player.index = i  # This index is for the client
      team = new Team(this, player, team, @numActive)
      player.team = team  # TODO: Deprecate
      @players.push(player)

    # if replacing = true, continueTurn won't execute end of turn effects
    @replacing = false

  getPlayer: (id) ->
    @players.find((p) -> p.id == id)

  getTeam: (id) ->
    @getPlayer(id).team

  getTeams: ->
    teams = []
    for player in @players
      teams.push(player.team)
    teams

  # Returns all opposing pokemon of a given pokemon.
  getOpponents: (pokemon) ->
    opponents = @getOpponentOwners(pokemon)
    teams = (opponent.team.slice(0, @numActive)  for opponent in opponents)
    _.flatten(teams)

  # Returns all opponent players of a given pokemon. In a 1v1 it returns
  # an array with only one opponent.
  getOpponentOwners: (pokemon) ->
    {id} = @getOwner(pokemon)
    (player  for player in @players when id != player.id)

  # Returns all active pokemon on the field belonging to both players.
  # Active pokemon include fainted pokemon that have not been switched out.
  getActivePokemon: ->
    pokemon = []
    for player in @players
      pokemon.push(player.team.getActivePokemon()...)
    pokemon

  getActiveAlivePokemon: ->
    pokemon = @getActivePokemon()
    pokemon.filter((p) -> p.isAlive())

  getActiveFaintedPokemon: ->
    pokemon = @getActivePokemon()
    pokemon.filter((p) -> p.isFainted())

  # Finds the Player attached to a certain Pokemon.
  getOwner: (pokemon) ->
    for player in @players
      return player  if pokemon in player.team.pokemon

  # Forces the owner of a Pokemon to switch.
  forceSwitch: (pokemon) ->
    player = @getOwner(pokemon)
    switches = player.team.getAliveBenchedPokemon().map((p) -> p.name)
    @requestAction(player, switches: switches)

  # Returns true if the Pokemon has yet to move.
  willMove: (pokemon) ->
    player = @getOwner(pokemon)
    (player.id of @playerActions) && @playerActions[player.id].type == 'move'

  # Returns the move associated with a Pokemon.
  peekMove: (pokemon) ->
    player = @getOwner(pokemon)
    @playerActions[player.id]?.move

  changeMove: (pokemon, move) ->
    player = @getOwner(pokemon)
    if @playerActions[player.id]?.type == 'move'
      @playerActions[player.id].move = move

  # Bumps a Pokemon to the front of a priority bracket.
  # If no bracket is provided, the Pokemon's current priority bracket is used.
  bump: (pokemon, bracket) ->
    if !bracket?
      action = @getAction(pokemon)
      bracket = @actionPriority(action, pokemon)

    # Find the priority segment associated with this pokemon
    index = @priorityQueue.map((o) -> o.pokemon).indexOf(pokemon)
    segment = @priorityQueue.splice(index, 1)[0]

    # Put segment in proper place in the queue
    for {priority}, i in @priorityQueue
      continue  if priority != bracket
      @priorityQueue.splice(i, 0, segment)
      break

  # Delays a Pokemon to the end of a priority bracket.
  # If no bracket is provided, the Pokemon's current priority bracket is used.
  delay: (pokemon, bracket) ->
    if !bracket?
      action = @getAction(pokemon)
      bracket = @actionPriority(action, pokemon)

    # Find the priority segment associated with this pokemon
    index = @priorityQueue.map((o) -> o.pokemon).indexOf(pokemon)
    segment = @priorityQueue.splice(index, 1)[0]

    # Put segment in proper place in the queue
    for i in [(@priorityQueue.length - 1)..0] by -1
      {priority} = @priorityQueue[i]
      continue  if priority != bracket
      @priorityQueue.splice(i + 1, 0, segment)
      break

  # Add `string` to a buffer that will be sent to each client.
  message: (string) ->
    player.tell(6, string)  for player in @players

  # Passing -1 to turns makes the weather last forever.
  setWeather: (weatherName, turns=-1) ->
    @message switch weatherName
      when Weather.SUN
        "The sunlight turned harsh!"
      when Weather.RAIN
        "It started to rain!"
      when Weather.SAND
        "A sandstorm kicked up!"
      when Weather.HAIL
        "It started to hail!"
    @weather = weatherName
    @weatherDuration = turns
    pokemon.informWeather(@weather)  for pokemon in @getActiveAlivePokemon()

  hasWeather: (weatherName) ->
    weather = (if @hasWeatherCancelAbilityOnField() then Weather.NONE else @weather)
    weatherName == weather

  stopWeather: ->
    @message switch @weather
      when Weather.SUN
        "The sunlight faded."
      when Weather.RAIN
        "The rain stopped."
      when Weather.SAND
        "The sandstorm subsided."
      when Weather.HAIL
        "The hail stopped."
    @setWeather(Weather.NONE)

  weatherMessage: ->
    switch @weather
      when Weather.SAND
        "The sandstorm rages."
      when Weather.HAIL
        "The hail crashes down."

  weatherUpkeep: ->
    if @weatherDuration == 1
      @stopWeather()
    else if @weatherDuration > 1
      @weatherDuration--

    message = @weatherMessage()
    @message(message)  if message?

    activePokemon = @getActivePokemon().filter((p) -> !p.isFainted())
    for pokemon in activePokemon
      continue  if pokemon.isWeatherDamageImmune(@weather)
      damage = pokemon.stat('hp') >> 4
      if @hasWeather(Weather.HAIL)
        @message "#{pokemon.name} is buffeted by the hail!"
        pokemon.damage(damage)
      else if @hasWeather(Weather.SAND)
        @message "#{pokemon.name} is buffeted by the sandstorm!"
        pokemon.damage(damage)

  hasWeatherCancelAbilityOnField: ->
    _.any @getActivePokemon(), (pokemon) ->
      pokemon.ability?.preventsWeather

  # Begins the turn. Replacements are performed and actions are requested
  # from each player. If no pokemon can move, then the battle engine
  # progresses to continueTurn. Otherwise, the battle waits for
  # user responses.
  beginTurn: ->
    @performReplacements()

    @turn++
    @priorityQueue = null

    p.tell(5, @turn)  for p in @players

    pokemon.resetBlocks()  for pokemon in @getActivePokemon()
    team.beginTurn()  for team in @getTeams()
    pokemon.beginTurn() for pokemon in @getActivePokemon()
    @attachments.query('beginTurn')

    # Send appropriate requests to players
    # TODO: If no Pokemon can move, request no actions and skip to continueTurn.
    # TODO: Struggle if no moves are usable
    for player in @players
      pokemon = player.team.at(0)
      continue  if @getAction(pokemon)
      pokeMoves = pokemon.validMoves()
      switches = player.team.getAliveBenchedPokemon()
      switches = []  if pokemon.isSwitchBlocked()
      canAct = pokeMoves.length > 0 || switches.length > 0
      @requestAction(player, moves: pokeMoves, switches: switches)  if canAct

  # A callback done after turn order is calculated for the first time.
  # Use this callback to edit the turn order after players have selected
  # their orders, but before the turn continues.
  afterTurnOrder: ->
    pokemon = @getActiveAlivePokemon()
    for p in pokemon
      p.attachments.query('afterTurnOrder')
    for p in pokemon
      p.item.afterTurnOrder(this, p)  if !p.isItemBlocked()

  # Continues the turn. This is called once all requests
  # have been submitted and the battle is ready to continue.
  continueTurn: ->
    @determineTurnOrder()
    for {pokemon} in @priorityQueue
      action = @getAction(pokemon)
      action.move?.beforeTurn?(this, pokemon)

    while @hasActionsLeft()
      {id, pokemon} = @priorityQueue.shift()
      continue  if pokemon.isFainted()

      action = @popAction(pokemon)
      switch action.type
        when 'switch' then @performSwitch(id, action.to)
        when 'move'   then @performMove(id, action.move)

      # Update Pokemon itself.
      # TODO: Is this the right place?
      for active in @getActiveAlivePokemon()
        active.update()

      # If a move adds a request to the queue, the request must be resolved
      # before the battle can continue.
      break  unless @areAllRequestsCompleted()

  # Performs end turn effects.
  endTurn: ->
    @attachments.query('endTurn')
    team.endTurn()  for team in @getTeams()
    pokemon.endTurn()  for pokemon in @getActiveAlivePokemon()
    @weatherUpkeep()

  attach: (klass, options = {}) ->
    options = _.clone(options)
    @attachments.push(klass, options, battle: this)

  unattach: (klass) ->
    attachment = @attachments.unattach(klass)
    delete attachment.battle  if attachment?
    attachment

  get: (attachment) ->
    @attachments.get(attachment)

  has: (attachment) ->
    @attachments.contains(attachment)

  endBattle: ->
    winner = @getWinner()
    for player in @players
      @message "#{winner.id} won!"
      @message "END BATTLE."

  getWinner: ->
    winner = null
    length = 0
    for player in @players
      newLength = player.team.getAlivePokemon().length
      if newLength > length
        length = newLength
        winner = player
    player

  isOver: ->
    @players.any((player) -> player.team.getAlivePokemon().length == 0)

  # Tells the player to execute a certain move by name. The move is added
  # to the list of player actions, which are executed once the turn continues.
  # TODO: Make this compatible with double battles by using the slot.
  #
  # player - the player object that will execute the move
  # moveName - the name of the move to execute
  #
  recordMove: (playerId, move) ->
    # Store the move that this player wants to make.
    @playerActions[playerId] =
      type: 'move'
      move: move

    delete @requests[playerId]

  # Tells the player to switch with a certain pokemon specified by position.
  # The switch is added to the list of player actions, which are executed
  # once the turn continues.
  # TODO: Make this compatible with double battles by using the slot.
  #
  # player - the player object that will execute the move
  # toPosition - the index of the pokemon to switch to
  #
  recordSwitch: (playerId, toPosition) ->
    # Record the switch
    @playerActions[playerId] =
      type: 'switch'
      to: toPosition

    delete @requests[playerId]

  getAction: (pokemon) ->
    {id} = @getOwner(pokemon)
    @playerActions[id]

  popAction: (pokemon) ->
    action = @getAction(pokemon)
    {id}   = @getOwner(pokemon)
    delete @playerActions[id]
    action

  cancelAction: (pokemon) ->
    @popAction(pokemon)
    index = @priorityQueue.map((o) -> o.pokemon).indexOf(pokemon)
    @priorityQueue.splice(index, 1)  if index >= 0

  requestAction: (player, validActions) ->
    # Normalize actions for the client
    {switches, moves} = validActions
    total = 0
    if switches?
      validActions.switches = switches.map((p) -> player.team.indexOf(p))
      total += validActions.switches.length
    if moves?
      validActions.moves = moves.map((m) -> m.name)
      total += validActions.moves.length

    return false  if total == 0

    # TODO: Delegate this kind of logic to the Player class.
    @requests[player.id] = validActions
    player.tell(4, validActions)
    return true

  # Returns true if all requests have been completed. False otherwise.
  areAllRequestsCompleted: ->
    requests = 0
    requests += 1  for id of @requests
    requests == 0

  # Returns true if any player's active Pokemon are fainted.
  areReplacementsNeeded: ->
    for player in @players
      if player.team.getActiveFaintedPokemon().length > 0
        return true
    return false

  # Force people to replace fainted Pokemon.
  requestFaintedReplacements: ->
    @replacing = true
    for player in @players
      team = player.team
      fainted = team.getActiveFaintedPokemon()
      if fainted.length > 0
        validActions = {switches: team.getAliveBenchedPokemon()}
        @requestAction(player, validActions)

  determineTurnOrder: ->
    ids = (id  for id of @playerActions)
    pq = []
    for id in ids
      pokemon = @getTeam(id).at(0)
      action = @getAction(pokemon)
      priority = @actionPriority(action, pokemon)
      pq.push({id, priority, pokemon})
    @priorityQueue = @sortActions(pq)
    @afterTurnOrder()
    @priorityQueue

  # Uses a Schwartzian transform to cut down on unnecessary calculations.
  # The game bitshifts priority and subpriority to the end and tacks on speed.
  # As a result, speed precision is 13 bits long; an overflow happens at 8191.
  # Trick Room replaces the Pokemon's speed with 0x2710 - speed.
  sortActions: (array) ->
    trickRoomed = @has(Attachment.TrickRoom)
    rng = @rng
    array = array.map (elem) ->
      speed = elem.pokemon.stat('speed')
      speed = 0x2710 - speed  if trickRoomed
      speed &= 8191
      integer = (elem.priority << 13) | speed
      [ elem, integer ]

    array.sort (a, b) ->
      diff = b[1] - a[1]
      diff = (if rng.next("turn order") < .5 then -1 else 1)  if diff == 0
      diff

    array.map (elem) -> elem[0]

  actionPriority: (action, pokemon) ->
    switch action.type
      when 'switch'
        5
      when 'move'
        {move} = action
        {priority} = move
        priority++  if move.isNonDamaging() && pokemon.hasAbility("Prankster")
        priority

  hasActionsLeft: ->
    @priorityQueue?.length > 0

  # Executed by @continueTurn
  performSwitch: (id, toPosition, options) ->
    player = @getPlayer(id)
    team = @getTeam(id)

    team.switch(player, 0, toPosition, options)

  # Executed by @beginTurn
  performReplacements: ->
    switched = []
    for id of @playerActions
      team = @getTeam(id)
      pokemon = team.at(0)
      @performSwitch(id, @popAction(pokemon).to, silent: true)
      switched.push team.at(0)
    # TODO: Switch-in events are ordered by speed
    for pokemon in switched
      pokemon.switchIn()

  # Executed by @continueTurn
  performMove: (id, move) ->
    player = @getPlayer(id)
    pokemon = @getTeam(id).at(0)
    targets = @getTargets(move, pokemon)
    targets = targets.filter((p) -> !p.isFainted())
    struggle = @getMove('Struggle')

    @message "#{pokemon.name} has no moves left!"  if move == struggle
    @message "#{player.id}'s #{pokemon.name} used #{move.name}!"

    if pokemon.pp(move) <= 0
      @message "But there was no PP left for the move!"
    else if pokemon.beforeMove(move, pokemon, targets) != false
      pokemon.reducePP(move)
      for target in targets.filter((t) -> t instanceof Pokemon && t.hasAbility("Pressure"))
        pokemon.reducePP(move)
      damage = move.execute(this, pokemon, targets)
      # TODO: Execute any after move events

      # TODO: If move is interrupted, do we record?
      # Record last move.
      @lastMove = move
      @lastPokemon = pokemon
      pokemon.recordMove(move)

    # TODO: Is this the right place...?
    pokemon.resetRecords()

    # Execute afterFaint events
    # TODO: If a Pokemon faints in an afterFaint, should it be added to this?
    for pokemon in @getActiveFaintedPokemon()
      @message "#{pokemon.name} fainted!"
      pokemon.afterFaint()

  getTargets: (move, user) ->
    player = @getOwner(user)
    {id, team} = player
    switch move.target
      when 'user'
        [ user ]
      when 'user-or-ally'
        [ @rng.choice(team.getActivePokemon()) ]
      when 'all-opponents'
        @getOpponents(user)
      when 'selected-pokemon'
        # TODO: Actually get selected Pokemon from client.
        [ @getOpponents(user)[0] ]
      when 'all-other-pokemon'
        @getActivePokemon().filter((p) -> p != user)
      when 'entire-field'
        @getActivePokemon()
      when 'random-opponent'
        pokemon = @getOpponents(user)
        [ @rng.choice(pokemon) ]
      when 'users-field'
        team.pokemon
      when 'specific-move'
        move.getTargets(this, user)
      when 'opponents-field'
        @getOpponentOwners(user)
      else
        throw new Error("Unimplemented target: #{move.target}.")

  getMove = (moveName) ->
    throw new Error("#{moveName} does not exist.")  if moveName not of Moves
    Moves[moveName]

  @getMove: getMove
  getMove: getMove

  getMoveList: ->
    MoveList

  toString: ->
    "[Battle id:#{@id} turn:#{@turn} weather:#{@weather}]"
