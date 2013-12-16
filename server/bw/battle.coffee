{_} = require 'underscore'
{Player} = require '../player'
{FakeRNG} = require './rng'
{Pokemon} = require './pokemon'
{Team} = require './team'
{Weather} = require './weather'
{Attachment, Attachments} = require './attachment'
{Protocol} = require '../../shared/protocol'
Query = require './queries'

require 'sugar'

class @Battle
  {Moves, MoveList, SpeciesData, FormeData} = require './data'
  Moves: Moves
  MoveList: MoveList
  SpeciesData: SpeciesData
  FormeData: FormeData

  generation: 'bw'

  actionMap:
    switch:
      priority: -> 5
      action: (action) ->
        @performSwitch(action.pokemon, action.to)
    move:
      priority: (action) ->
        {move} = action
        {priority} = move
        action.pokemon.editPriority(priority, move)
      action: (action) ->
        @performMove(action.pokemon, action.move)

  constructor: (@id, attributes = {}) ->
    # Number of pokemon on each side of the field
    @numActive = attributes.numActive || 1

    # An array of conditions like clauses or team preview that this battle has.
    @conditions = attributes.conditions || []

    # Stores the current turn of the battle
    @turn = 0

    # Stores the actions each player is about to make
    # Keyed by player.id
    @pokemonActions = []

    # Stores the current requests for action.
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

    # Array of players partaking in the battle.
    @players = []

    # Array of spectators scouting these fine, upstanding players.
    @spectators = []

    # Stores last move used
    @lastMove = null

    # Stores last pokemon that moved
    @lastPokemon = null

    # Stores the confusion recoil move as it may be different cross-generations
    @confusionMove = @getMove('Confusion Recoil')

    # Stores the Struggle move as it is different cross-generation
    @struggleMove = @getMove('Struggle')

    # Stores attachments on the battle itself.
    @attachments = new Attachments()

    # Stores an ongoing log of the battle
    @log = []

    for object, i in attributes.players
      {player, team} = object
      player = new Player(player)
      player.index = i  # This index is for the client
      team = new Team(this, player, team, @numActive)
      player.team = team  # TODO: Deprecate
      @players.push(player)
      @addSpectator(player)

    @replacing = false
    @finished = false

  begin: ->
    teams = (player.team.toJSON(hidden: true)  for player in @players)
    @tell(Protocol.BEGIN_BATTLE, teams)
    for player in @players
      player.tell(Protocol.RECEIVE_TEAM, player.team.toJSON())
    # TODO: Merge this with performReplacements?
    for player in @players
      for slot in [0...@numActive]
        pokemon = player.team.at(slot)
        continue  if !pokemon
        @performReplacement(pokemon, slot)
    # TODO: Switch-in events are ordered by speed
    for pokemon in @getActivePokemon()
      pokemon.switchIn()
      # TODO: This is not part of the regular performReplacements
      pokemon.turnsActive = 1
    @beginTurn()

  getPlayer: (id) ->
    @players.find((p) -> p.id == id)

  getTeam: (id) ->
    @getPlayer(id).team

  getTeams: ->
    (player.team  for player in @players)

  # Returns all opposing pokemon of a given pokemon.
  getOpponents: (pokemon) ->
    opponents = @getOpponentOwners(pokemon)
    teams = (opponent.team.slice(0, @numActive)  for opponent in opponents)
    opponents = _.flatten(teams)
    opponents = opponents.filter((p) -> p.isAlive())
    opponents

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

  getSlotNumber: (pokemon) ->
    pokemon.team.indexOf(pokemon)

  # Forces the owner of a Pokemon to switch.
  forceSwitch: (pokemon) ->
    player = @getOwner(pokemon)
    switches = player.team.getAliveBenchedPokemon()
    slot = @getSlotNumber(pokemon)
    @requestActions(player, [ {switches, slot} ])

  # Returns true if the Pokemon has yet to move.
  willMove: (pokemon) ->
    action = @getAction(pokemon)
    action?.type == 'move'

  # Returns the move associated with a Pokemon.
  peekMove: (pokemon) ->
    @getAction(pokemon)?.move

  changeMove: (pokemon, move) ->
    action = @getAction(pokemon)
    if action?.type == 'move'
      action.move = move

  # Bumps a Pokemon to the front of a priority bracket.
  # If no bracket is provided, the Pokemon's current priority bracket is used.
  bump: (pokemon, bracket) ->
    if !bracket?
      action = @getAction(pokemon)
      bracket = @actionPriority(action)

    # Find the priority segment associated with this pokemon
    index = @pokemonActions.map((o) -> o.pokemon).indexOf(pokemon)
    segment = @pokemonActions.splice(index, 1)[0]

    # Put segment in proper place in the queue
    for action, i in @pokemonActions
      continue  if @actionPriority(action) != bracket
      @pokemonActions.splice(i, 0, segment)
      break

  # Delays a Pokemon to the end of a priority bracket.
  # If no bracket is provided, the Pokemon's current priority bracket is used.
  delay: (pokemon, bracket) ->
    if !bracket?
      action = @getAction(pokemon)
      bracket = @actionPriority(action)

    # Find the priority segment associated with this pokemon
    index = @pokemonActions.map((o) -> o.pokemon).indexOf(pokemon)
    segment = @pokemonActions.splice(index, 1)[0]

    # Put segment in proper place in the queue
    for i in [(@pokemonActions.length - 1)..0] by -1
      action = @pokemonActions[i]
      continue  if @actionPriority(action) != bracket
      @pokemonActions.splice(i + 1, 0, segment)
      break

  # Add `string` to a buffer that will be sent to each client.
  message: (string) ->
    @tell(Protocol.RAW_MESSAGE, string)

  # Tells every spectator something.
  tell: (args...) ->
    spectator.tell(args...)  for spectator in @spectators
    @log.push(args)
    true

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

  # Begins the turn. Actions are requested from each player. If no pokemon can
  # move, then the battle engine progresses to continueTurn. Otherwise, the
  # battle waits for user responses.
  beginTurn: ->
    @performReplacements()  if @replacing

    @turn++

    @tell(Protocol.START_TURN, @turn)

    pokemon.resetBlocks()  for pokemon in @getActivePokemon()
    @query('beginTurn')

    # Send appropriate requests to players
    for player in @players
      actions = []
      for slot in [0...@numActive]
        pokemon = player.team.at(slot)
        continue  if !pokemon || @getAction(pokemon)
        moves = pokemon.validMoves()
        switches = player.team.getAliveBenchedPokemon()
        switches = []  if pokemon.isSwitchBlocked()
        # This guarantees the user always has a move to pick.
        moves.push(@struggleMove)  if moves.length == 0
        actions.push({moves, switches, slot})
      @requestActions(player, actions)

  # A callback done after turn order is calculated for the first time.
  # Use this callback to edit the turn order after players have selected
  # their orders, but before the turn continues.
  afterTurnOrder: ->
    pokemon = @getActiveAlivePokemon()
    p.afterTurnOrder()  for p in pokemon

  # Continues the turn. This is called once all requests
  # have been submitted and the battle is ready to continue.
  continueTurn: ->
    @determineTurnOrder()
    for action in @pokemonActions
      action.move?.beforeTurn?(this, action.pokemon)

    while @hasActionsLeft()
      action = @pokemonActions.shift()
      {pokemon} = action
      continue  if pokemon.isFainted()

      @actionMap[action.type]["action"].call(this, action)
      @performFaints()

      # Update Pokemon itself.
      # TODO: Is this the right place?
      for active in @getActiveAlivePokemon()
        active.update()

      # If a move adds a request to the queue, the request must be resolved
      # before the battle can continue.
      break  unless @areAllRequestsCompleted()

  # Performs end turn effects.
  endTurn: ->
    @weatherUpkeep()
    @query("endTurn")
    for pokemon in @getActivePokemon()
      pokemon.turnsActive += 1
    @performFaints()

  attach: (klass, options = {}) ->
    options = _.clone(options)
    attachment = @attachments.push(klass, options, battle: this)
    if attachment then @tell(Protocol.BATTLE_ATTACH, attachment.name)
    attachment

  unattach: (klass) ->
    attachment = @attachments.unattach(klass)
    if attachment then @tell(Protocol.BATTLE_UNATTACH, attachment.name)
    attachment

  get: (attachment) ->
    @attachments.get(attachment)

  has: (attachment) ->
    @attachments.contains(attachment)

  endBattle: ->
    winner = @getWinner()
    @tell(Protocol.END_BATTLE, winner.index)

  getWinner: ->
    winner = null
    if @players.all((player) -> player.team.getAlivePokemon().length > 0)
      return winner
    length = 0
    for player in @players
      newLength = player.team.getAlivePokemon().length
      if newLength > length
        length = newLength
        winner = player
    winner

  isOver: ->
    @finished || @players.any((player) -> player.team.getAlivePokemon().length == 0)

  hasStarted: ->
    @turn >= 1

  getAllAttachments: ->
    array = @attachments.all()
    array.push(@getTeams().map((t) -> t.attachments.all()))
    array.push(@getActivePokemon().map((p) -> p.attachments.all()))
    _.flatten(array)

  query: (eventName) ->
    Query(eventName, @getAllAttachments())

  # Tells the player to execute a certain move by name. The move is added
  # to the list of player actions, which are executed once the turn continues.
  #
  # player - the player object that will execute the move
  # moveName - the name of the move to execute
  #
  recordMove: (playerId, move, forSlot = 0) ->
    pokemon = @getTeam(playerId).at(forSlot)
    action = {type: 'move', move: move, pokemon: pokemon}
    @pokemonActions.push(action)  unless @getAction(pokemon)
    @removeRequest(playerId, forSlot)

  # Tells the player to switch with a certain pokemon specified by position.
  # The switch is added to the list of player actions, which are executed
  # once the turn continues.
  #
  # player - the player object that will execute the move
  # toPosition - the index of the pokemon to switch to
  #
  recordSwitch: (playerId, toPosition, forSlot = 0) ->
    pokemon = @getTeam(playerId).at(forSlot)
    action = {type: 'switch', to: toPosition, pokemon: pokemon}
    @pokemonActions.push(action)  unless @getAction(pokemon)
    @removeRequest(playerId, forSlot)

  removeRequest: (playerId, forSlot = 0) ->
    actions = @requests[playerId] || []
    for {slot}, i in actions
      if slot == forSlot
        actions.splice(i, 1)
        delete @requests[playerId]  if actions.length == 0
        break

  requestFor: (pokemon) ->
    {id}    = pokemon.player
    forSlot = pokemon.team.indexOf(pokemon)
    actions = @requests[id] || []
    for action in actions
      if action.slot == forSlot
        return action
    return null

  getAction: (pokemon) ->
    for action in @pokemonActions
      if action.pokemon == pokemon && action.type in [ 'move', 'switch' ]
        return action
    return null

  popAction: (pokemon) ->
    action = @getAction(pokemon)
    if action
      index = @pokemonActions.indexOf(action)
      @pokemonActions.splice(index, 1)
    action

  cancelAction: (pokemon) ->
    action = @popAction(pokemon)
    action = @popAction(pokemon)  while action?

  requestActions: (player, validActions) ->
    # Normalize actions for the client
    # TODO: Should not need to do this here.
    total = 0
    for action in validActions
      {switches, moves} = action
      if switches?
        action.switches = switches.map((p) -> player.team.indexOf(p))
        total += action.switches.length
      if moves?
        action.moves = moves.map((m) -> m.name)
        total += action.moves.length

    return false  if total == 0

    # TODO: Delegate this kind of logic to the Player class.
    @requests[player.id] = validActions
    player.tell(Protocol.REQUEST_ACTIONS, validActions)
    return true

  # Returns true if all requests have been completed. False otherwise.
  areAllRequestsCompleted: ->
    total = 0
    total += (request  for request of @requests).length
    total == 0

  # Returns true if any player's active Pokemon are fainted.
  areReplacementsNeeded: ->
    @getActiveFaintedPokemon().length > 0

  # Force people to replace fainted Pokemon.
  requestFaintedReplacements: ->
    @replacing = true
    for player in @players
      team = player.team
      fainted = team.getActiveFaintedPokemon()
      size = fainted.length
      if size > 0
        benched = team.getAliveBenchedPokemon()
        validActions = ({switches: benched, slot: x}  for x in [0...size])
        @requestActions(player, validActions)

  determineTurnOrder: ->
    @sortActions()
    @afterTurnOrder()
    @pokemonActions

  # Uses a Schwartzian transform to cut down on unnecessary calculations.
  # The game bitshifts priority and subpriority to the end and tacks on speed.
  # As a result, speed precision is 13 bits long; an overflow happens at 8191.
  # Trick Room replaces the Pokemon's speed with 0x2710 - speed.
  sortActions: ->
    trickRoomed = @has(Attachment.TrickRoom)
    array = @pokemonActions.map (action) =>
      {pokemon} = action
      priority = @actionPriority(action)
      speed = pokemon.stat('speed')
      speed = 0x2710 - speed  if trickRoomed
      speed &= 8191
      integer = (priority << 13) | speed
      [ action, integer ]

    array.sort (a, b) =>
      diff = b[1] - a[1]
      diff = (if @rng.next("turn order") < .5 then -1 else 1)  if diff == 0
      diff

    @pokemonActions = array.map (elem) => elem[0]

  actionPriority: (action) ->
    @actionMap[action.type]["priority"].call(this, action)

  hasActionsLeft: ->
    @pokemonActions.length > 0

  # Executed by @continueTurn
  performSwitch: (pokemon, toPosition) ->
    pokemon.team.switch(pokemon, toPosition)

  performReplacement: (pokemon, toPosition) ->
    pokemon.team.replace(pokemon, toPosition)

  # Executed by @beginTurn
  performReplacements: ->
    @replacing = false
    switched = []
    while @hasActionsLeft()
      {pokemon, to} = @pokemonActions.shift()
      switched.push @performReplacement(pokemon, to)
    # TODO: Switch-in events are ordered by speed
    for pokemon in switched
      pokemon.team.switchIn(pokemon)

  # Executed by @continueTurn
  performMove: (pokemon, move) ->
    targets = @getTargets(move, pokemon)

    @message "#{pokemon.name} has no moves left!"  if move == @struggleMove

    if pokemon.pp(move) <= 0
      # TODO: Send move id instead
      pokemon.tell(Protocol.MAKE_MOVE, move.name)
      @message "But there was no PP left for the move!"
      # TODO: Is this the right place...?
      pokemon.resetRecords()
    else if pokemon.beforeMove(move, pokemon, targets) != false
      pokemon.reducePP(move)
      for target in targets.filter((t) -> t instanceof Pokemon && t.hasAbility("Pressure"))
        pokemon.reducePP(move)
      @executeMove(move, pokemon, targets)

  # TODO: Put in priority queue
  performFaints: ->
    # Execute afterFaint events
    # TODO: If a Pokemon faints in an afterFaint, should it be added to this?
    for pokemon in @getActiveFaintedPokemon()
      continue  if pokemon.fainted
      pokemon.faint()

  executeMove: (move, pokemon, targets) ->
    # TODO: Send move id instead
    pokemon.tell(Protocol.MAKE_MOVE, move.name)
    move.execute(this, pokemon, targets)
    # TODO: Execute any after move events

    # Record last move.
    @lastMove = move
    @lastPokemon = pokemon
    # TODO: Only record if none exists yet for this turn.
    pokemon.recordMove(move)

    # TODO: Is this the right place...?
    pokemon.resetRecords()

  getTargets: (move, user) ->
    {team} = user
    targets = switch move.target
      when 'user'
        [ user ]
      when 'user-or-ally'
        [ @rng.choice(team.getActivePokemon()) ]
      when 'all-opponents'
        @getOpponents(user)
      when 'selected-pokemon'
        # TODO: Actually get selected Pokemon from client.
        [ @getOpponentOwners(user)[0].team.first() ]
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
    if move.target != 'opponents-field'
      targets = targets.filter((p) -> !p.isFainted())
    return targets

  getMove: (moveName) ->
    throw new Error("#{moveName} does not exist.")  if moveName not of @Moves
    @Moves[moveName]

  findMove: (condition) ->
    for move in @MoveList
      if condition(move) then return move
    return null

  addSpectator: (spectator) ->
    return  if spectator.id in @spectators.map((s) -> s.id)
    spectator = new Player(spectator)  if spectator not instanceof Player
    @spectators.push(spectator)
    teams = @getTeams().map((team) -> team.toJSON())
    index = spectator.index
    spectators = @spectators.map((s) -> s.toJSON())
    spectator.send('spectate battle', @id, @generation, @numActive, index, teams, spectators, @log)
    spectatorJSON = spectator.toJSON()
    s.send('join battle', @id, spectatorJSON)  for s in @spectators

  removeSpectator: (spectator) ->
    for s, i in @spectators
      if s.id == spectator.id
        @spectators.splice(i, 1)
        spectatorJSON = s.toJSON()
        s.send('leave battle', @id, spectatorJSON)  for s in @spectators
        break

  hasCondition: (condition) ->
    condition in @conditions

  forfeit: (user) ->
    player = @players.find((p) -> p.user == user)
    return  unless player
    @tell(Protocol.FORFEIT_BATTLE, player.index)
    @finished = true

  toString: ->
    "[Battle id:#{@id} turn:#{@turn} weather:#{@weather}]"
