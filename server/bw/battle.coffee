{_} = require 'underscore'
{User, MaskedUser} = require '../user'
{FakeRNG} = require './rng'
{Pokemon} = require './pokemon'
{Team} = require './team'
{Weather} = require '../../shared/weather'
{Attachment, Attachments, Status} = require './attachment'
{Protocol} = require '../../shared/protocol'
Query = require './queries'
{EventEmitter} = require 'events'

require 'sugar'

# Represents a single ongoing battle
class @Battle extends EventEmitter
  {Moves, MoveList, SpeciesData, FormeData} = require './data'
  Moves: Moves
  MoveList: MoveList
  SpeciesData: SpeciesData
  FormeData: FormeData

  generation: 'bw'

  actionMap:
    switch:
      priority: -> 10
      action: (action) ->
        @performSwitch(action.pokemon, action.to)
    move:
      priority: (action) ->
        {move} = action
        {priority} = move
        action.pokemon.editPriority(priority, move)
      action: (action) ->
        @performMove(action.pokemon, action.move)

  constructor: (@id, players, attributes = {}) ->
    # Number of pokemon on each side of the field
    @numActive = attributes.numActive || 1

    # An array of conditions like clauses or team preview that this battle has.
    # TODO: Remove
    @conditions = (attributes.conditions && _.clone(attributes.conditions))
    @conditions ||= []

    # Stores the current turn of the battle
    @turn = 0

    # Stores the actions each player is about to make
    @pokemonActions = []

    # Stores the current and completed requests for action.
    # Keyed by player.id
    @requests = {}
    @completedRequests = {}

    # Creates a RNG for this battle.
    @rng = new FakeRNG()

    # Current battle weather.
    @weather = Weather.NONE

    # Current turn duration for the weather. -1 means infinity.
    @weatherDuration = -1

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

    # Teams for each player, keyed by player id.
    @teams = {}

    # Battle update information for each player, keyed by player id.
    @queues = {}

    # Holds all playerIds. The location in this array is the player's index.
    @playerIds = []

    # Maps player id -> alt name.
    @altMappings = attributes.alts || {}

    # Player ids where the id has been replaced with the alt name
    @maskedPlayerIds = []

    # Populates @playerIds and creates the teams for each player
    for playerId, team of players
      maskedName = @altMappings[playerId] || playerId
      @playerIds.push(playerId)
      @maskedPlayerIds.push(maskedName)
      # TODO: Get the actual player object and use player.name
      @teams[playerId] = new Team(this, playerId, maskedName, team, @numActive)

    # Holds battle state information
    @replacing = false
    @finished = false

    @once 'end', (winnerId) ->
      @finished = true

    # Store when the battle was created
    @createdAt = Date.now()

  begin: ->
    @tell(Protocol.INITIALIZE, @getTeams().map((t) -> t.toJSON(hidden: true)))
    for playerId in @playerIds
      @tellPlayer(playerId, Protocol.RECEIVE_TEAM, @getTeam(playerId).toJSON())

    if @listeners('beforeStart').length > 0
      @emit('beforeStart')
    else
      @startBattle()

  startBattle: ->
    @emit('start')
    @tell(Protocol.START_BATTLE)
    # TODO: Merge this with performReplacements?
    for playerId in @playerIds
      for slot in [0...@numActive]
        pokemon = @getTeam(playerId).at(slot)
        continue  if !pokemon
        @performReplacement(pokemon, slot)
    # TODO: Switch-in events are ordered by speed
    for pokemon in @getActivePokemon()
      pokemon.team.switchIn(pokemon)
      pokemon.turnsActive = 1

    @beginTurn()

  getPlayerIndex: (playerId) ->
    index = @playerIds.indexOf(playerId)
    return (if index == -1 then null else index)

  getTeam: (playerId) ->
    @teams[playerId]

  # Returns teams in order of index.
  getTeams: ->
    (@getTeam(playerId)  for playerId in @playerIds)

  # Returns non-fainted opposing pokemon of a given pokemon.
  getOpponents: (pokemon) ->
    opponents = @getAllOpponents(pokemon)
    opponents = opponents.filter((p) -> p.isAlive())
    opponents

  # Returns all opposing pokemon of a given pokemon.
  getAllOpponents: (pokemon) ->
    opponents = @getOpponentOwners(pokemon)
    teams = (@getTeam(playerId).slice(0, @numActive)  for playerId in opponents)
    opponents = _.flatten(teams)
    opponents

  # Returns all opponent players of a given pokemon. In a 1v1 it returns
  # an array with only one opponent.
  getOpponentOwners: (pokemon) ->
    id = @getOwner(pokemon)
    (playerId  for playerId in @playerIds when id != playerId)

  # Returns all active pokemon on the field belonging to both players.
  # Active pokemon include fainted pokemon that have not been switched out.
  getActivePokemon: ->
    pokemon = []
    for team in @getTeams()
      pokemon.push(team.getActivePokemon()...)
    pokemon

  getActiveAlivePokemon: ->
    pokemon = @getActivePokemon()
    pokemon.filter((p) -> p.isAlive())

  getActiveFaintedPokemon: ->
    pokemon = @getActivePokemon()
    pokemon.filter((p) -> p.isFainted())

  # Finds the Player attached to a certain Pokemon.
  getOwner: (pokemon) ->
    for playerId in @playerIds
      return playerId  if @getTeam(playerId).contains(pokemon)

  getSlotNumber: (pokemon) ->
    pokemon.team.indexOf(pokemon)

  # Forces the owner of a Pokemon to switch.
  forceSwitch: (pokemon) ->
    return false  if @isOver()
    playerId = @getOwner(pokemon)
    switches = pokemon.team.getAliveBenchedPokemon()
    slot = @getSlotNumber(pokemon)
    @cancelAction(pokemon)
    @requestActions(playerId, [ {switches, slot} ])

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
      break  if @actionPriority(action) <= bracket
    @pokemonActions.splice(i, 0, segment)

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
      break  if @actionPriority(action) >= bracket
    @pokemonActions.splice(i + 1, 0, segment)

  # Add `string` to a buffer that will be sent to each client.
  message: (string) ->
    @tell(Protocol.RAW_MESSAGE, string)

  # Tells every spectator something.
  tell: (args...) ->
    spectatorIds = _.unique(@spectators.map((s) -> s.id))
    @tellPlayer(spectatorId, args...)  for spectatorId in spectatorIds
    @log.push(args)
    true

  tellPlayer: (id, args...) ->
    @queues[id] ?= []
    @queues[id].push(args)

  # Passing -1 to turns makes the weather last forever.
  setWeather: (weatherName, turns=-1) ->
    message = switch weatherName
      when Weather.SUN  then "The sunlight turned harsh!"
      when Weather.RAIN then "It started to rain!"
      when Weather.SAND then "A sandstorm kicked up!"
      when Weather.HAIL then "It started to hail!"
      else
        switch @weather
          when Weather.SUN  then "The sunlight faded."
          when Weather.RAIN then "The rain stopped."
          when Weather.SAND then "The sandstorm subsided."
          when Weather.HAIL then "The hail stopped."
    @message(message)  if message
    @weather = weatherName
    @weatherDuration = turns
    pokemon.informWeather(@weather)  for pokemon in @getActiveAlivePokemon()
    @tell(Protocol.WEATHER_CHANGE, @weather)

  hasWeather: (weatherName) ->
    return @weather != Weather.NONE  if !weatherName
    weather = (if @hasWeatherCancelAbilityOnField() then Weather.NONE else @weather)
    weatherName == weather

  weatherMessage: ->
    switch @weather
      when Weather.SAND
        "The sandstorm rages."
      when Weather.HAIL
        "The hail crashes down."

  weatherUpkeep: ->
    if @weatherDuration == 1
      @setWeather(Weather.NONE)
    else if @weatherDuration > 1
      @weatherDuration--

    message = @weatherMessage()
    @message(message)  if message?

    activePokemon = @getActivePokemon().filter((p) -> !p.isFainted())
    for pokemon in activePokemon
      continue  if pokemon.isWeatherDamageImmune(@weather)
      damage = pokemon.stat('hp') >> 4
      if @hasWeather(Weather.HAIL)
        if pokemon.damage(damage)
          @message "#{pokemon.name} is buffeted by the hail!"
      else if @hasWeather(Weather.SAND)
        if pokemon.damage(damage)
          @message "#{pokemon.name} is buffeted by the sandstorm!"

  hasWeatherCancelAbilityOnField: ->
    _.any @getActivePokemon(), (pokemon) ->
      pokemon.ability?.preventsWeather

  # Begins the turn. Actions are requested from each player. If no pokemon can
  # move, then the battle engine progresses to continueTurn. Otherwise, the
  # battle waits for user responses.
  beginTurn: ->
    @turn++
    @tell(Protocol.START_TURN, @turn)
    pokemon.resetBlocks()  for pokemon in @getActivePokemon()
    @query('beginTurn')
    @emit('beginTurn')

    # Send appropriate requests to players
    for playerId in @playerIds
      actions = []
      for slot in [0...@numActive]
        team = @getTeam(playerId)
        pokemon = team.at(slot)
        continue  if !pokemon || @getAction(pokemon)
        moves = pokemon.validMoves()
        switches = team.getAliveBenchedPokemon()
        switches = []  if pokemon.isSwitchBlocked()
        # This guarantees the user always has a move to pick.
        moves.push(@struggleMove)  if moves.length == 0
        actions.push({moves, switches, slot})
      @requestActions(playerId, actions)

  # A callback done after turn order is calculated for the first time.
  # Use this callback to edit the turn order after players have selected
  # their orders, but before the turn continues.
  afterTurnOrder: ->
    pokemon = @getActiveAlivePokemon()
    p.afterTurnOrder()  for p in pokemon

  # Continues the turn. This is called once all requests
  # have been submitted and the battle is ready to continue.
  continueTurn: ->
    # We're done processing requests, so cancelling shouldn't be possible anymore.
    # Clean the completed requests
    @completedRequests = {}

    @emit('continueTurn')

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
    @lastPokemon = null
    @weatherUpkeep()
    @query("endTurn")
    for pokemon in @getActivePokemon()
      pokemon.turnsActive += 1
    @checkForReplacements()

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
    return  if @finished
    winnerId = @getWinner()
    winnerIndex = @getPlayerIndex(winnerId)
    @tell(Protocol.END_BATTLE, winnerIndex)
    @emit('end', winnerId)

  getWinner: ->
    winner     = null

    # If each player has the same number of pokemon alive, return null.
    teamLength = @getTeam(@playerIds[0]).getAlivePokemon().length
    playerSize = @playerIds.length
    count      = 1
    for i in [1...playerSize] by 1
      count++  if teamLength == @getTeam(@playerIds[i]).getAlivePokemon().length
    return null  if count == playerSize

    # Otherwise, return the player with the most pokemon alive.
    length = 0
    for playerId in @playerIds
      newLength = @getTeam(playerId).getAlivePokemon().length
      if newLength > length
        length = newLength
        winner = playerId
    return winner

  isOver: ->
    @finished || @playerIds.any((id) => @getTeam(id).getAlivePokemon().length == 0)

  hasStarted: ->
    @turn >= 1

  getAllAttachments: ->
    array = @attachments.all()
    array.push(@getTeams().map((t) -> t.attachments.all()))
    array.push(@getActivePokemon().map((p) -> p.attachments.all()))
    _.flatten(array)

  isPokemon: (maybePokemon) ->
    maybePokemon instanceof Pokemon

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
    action = @addAction(type: 'move', move: move, pokemon: pokemon)
    @removeRequest(playerId, action, forSlot)

  # Tells the player to switch with a certain pokemon specified by position.
  # The switch is added to the list of player actions, which are executed
  # once the turn continues.
  #
  # player - the player object that will execute the move
  # toPosition - the index of the pokemon to switch to
  #
  recordSwitch: (playerId, toPosition, forSlot = 0) ->
    pokemon = @getTeam(playerId).at(forSlot)
    action = @addAction(type: 'switch', to: toPosition, pokemon: pokemon)
    @removeRequest(playerId, action, forSlot)

  addAction: (action) ->
    unless @getAction(action.pokemon)
      @pokemonActions.push(action)
      @emit('addAction', action.pokemon.playerId, action)
    return action

  removeRequest: (playerId, action, forSlot) ->
    if arguments.length == 2
      [action, forSlot] = [null, forSlot]
    forSlot ?= 0
    playerRequests = @requests[playerId] || []
    for request, i in playerRequests
      if request.slot == forSlot
        if action
          completed = { request, action }
          @completedRequests[playerId] ?= []
          @completedRequests[playerId].push(completed)

        playerRequests.splice(i, 1)
        delete @requests[playerId]  if playerRequests.length == 0
        break

  # Cancels the most recent completed request made by a certain player
  # Returns true if the cancel succeeded, and false if it didn't.
  undoCompletedRequest: (playerId) ->
    return false  if @isOver()
    return false  if @areAllRequestsCompleted()
    return false  if not @completedRequests[playerId]
    return false  if @completedRequests[playerId].length == 0
    return false  if playerId not in @playerIds

    {request, action} = @completedRequests[playerId].pop()

    # Add the cancelled request to the beginning of @requests
    @requests[playerId] ?= []
    @requests[playerId].unshift(request)

    # Remove the related pokemon actions. There may be more than one.
    index = 0
    while index < @pokemonActions.length
      if @pokemonActions[index].pokemon.playerId == playerId
        @pokemonActions.splice(index, 1)
      else
        index += 1

    @tellPlayer(playerId, Protocol.CANCEL_SUCCESS)

    @emit('undoCompletedRequest', playerId)
    return true

  requestFor: (pokemon) ->
    playerId = @getOwner(pokemon)
    forSlot  = @getSlotNumber(pokemon)
    actions  = @requests[playerId] || []
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

  requestActions: (playerId, validActions) ->
    # Normalize actions for the client
    # TODO: Should not need to do this here.
    total = 0
    for action in validActions
      {switches, moves} = action
      if switches?
        action.switches = switches.map((p) => @getSlotNumber(p))
        total += action.switches.length
      if moves?
        action.moves = moves.map((m) -> m.name)
        total += action.moves.length

    return false  if total == 0

    @requests[playerId] = validActions
    @sendRequestTo(playerId)
    @emit('requestActions', playerId)
    return true

  sendRequestTo: (playerId) ->
    @tellPlayer(playerId, Protocol.REQUEST_ACTIONS, @requests[playerId])

  # Returns true if all requests have been completed. False otherwise.
  areAllRequestsCompleted: ->
    total = 0
    total += (request  for request of @requests).length
    total == 0

  checkForReplacements: ->
    @performFaints()
    if @isOver()
      @endBattle()
    else if @areReplacementsNeeded()
      @requestFaintedReplacements()
    else
      @beginTurn()

  # Returns true if any player's active Pokemon are fainted.
  areReplacementsNeeded: ->
    @getActiveFaintedPokemon().length > 0

  # Force people to replace fainted Pokemon.
  requestFaintedReplacements: ->
    @replacing = true
    for playerId in @playerIds
      team = @getTeam(playerId)
      fainted = team.getActiveFaintedPokemon()
      size = fainted.length
      if size > 0
        benched = team.getAliveBenchedPokemon()
        validActions = ({switches: benched, slot: x}  for x in [0...size])
        @requestActions(playerId, validActions)

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
      pokemon.turnsActive = 1

    # Pokemon may have fainted upon switch-in; we need to check.
    @checkForReplacements()

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
    else
      if pokemon.beforeMove(move, pokemon, targets) != false
        pokemon.reducePP(move)
        pressureTargets = targets.filter (t) ->
          t instanceof Pokemon && t.hasAbility("Pressure") && !t.team.contains(pokemon)
        for target in pressureTargets
          pokemon.reducePP(move)
        @executeMove(move, pokemon, targets)
      # After the move finishes (whether it executed properly or not, e.g. par)
      pokemon.afterMove(move, pokemon, targets)

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
        pokemon = @getOpponents(user)
        [ @rng.choice(pokemon, "selected pokemon target") ]
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
      targets = targets.filter((p) -> p && !p.isFainted())
    return targets

  getMove: (moveName) ->
    throw new Error("#{moveName} does not exist.")  if moveName not of @Moves
    @Moves[moveName]

  findMove: (condition) ->
    for move in @MoveList
      if condition(move) then return move
    return null

  getAttachment: (attachmentName) ->
    Attachment[attachmentName]

  getAilmentEffect: (move) ->
    switch move.ailmentId
      when "confusion"   then Attachment.Confusion
      when "paralysis"   then Status.Paralyze
      when "freeze"      then Status.Freeze
      when "burn"        then Status.Burn
      when "sleep"       then Status.Sleep
      when "poison"      then Status.Poison
      when "toxic"       then Status.Toxic
      when "yawn"        then Attachment.Yawn
      when "infatuation" then Attachment.Attract
      when "disable"     then Attachment.Disable
      when "ingrain"     then Attachment.Ingrain
      when "leech-seed"  then Attachment.LeechSeed
      when "torment"     then Attachment.Torment
      when "perish-song" then Attachment.PerishSong
      when "embargo"     then Attachment.Embargo
      when "telekinesis" then Attachment.Telekinesis
      when "nightmare"   then Attachment.Nightmare
      when "unknown"
        switch move.name
          when "Tri Attack"
            triAttackEffects = [ Status.Paralyze, Status.Burn, Status.Freeze ]
            @rng.choice(triAttackEffects, "tri attack effect")
          else throw new Error("Unrecognized unknown ailment for #{move.name}")
      else throw new Error("Unrecognized ailment: #{move.ailmentId} for #{move.name}")

  addSpectator: (spectator) ->
    return  if @spectators.some((s) -> s.id == spectator.id)
    
    # Mask the spectator with the alt name if relevant
    altName = @altMappings[spectator.id]
    if altName
      spectator = new MaskedUser(spectator, altName)

    @spectators.push(spectator)
    index = @getPlayerIndex(spectator.id)

    # Get rid of non-unique spectators?
    spectators = @spectators.map((s) -> s.toJSON())
    spectator.send('spectateBattle',
      @id, @generation, @numActive,
      index, @maskedPlayerIds, spectators, @log)

    if spectator.id in @playerIds
      @tellPlayer(spectator.id, Protocol.RECEIVE_TEAM, @getTeam(spectator.id).toJSON())
    
    # TODO: Only do if spectator id has not joined yet.
    @broadcast('joinBattle', @id, spectator.name)

  removeSpectator: (spectator) ->
    for s, i in @spectators
      if s.id == spectator.id
        @spectators.splice(i, 1)
        @broadcast('leaveBattle', @id, spectator.name)
        break

  forfeit: (id) ->
    return  if @isOver()
    index = @getPlayerIndex(id)
    return  unless index?
    @tell(Protocol.FORFEIT_BATTLE, index)
    winnerId = @playerIds[1 - index]
    @emit('end', winnerId)

  # Proxies arguments the `send` function for all spectators.
  broadcast: ->
    s.send.apply(s, arguments)  for s in @spectators

  # Sends battle updates to each spectator.
  sendUpdates: ->
    # Send battle updates to each spectator. Keep in mind that multiple
    # spectators can belong to a single id, due to multiple clients.
    # This is why we cleanup after all spectators are iterated through.
    for spectator in @spectators
      queue = @queues[spectator.id]
      continue  if !queue || queue.length == 0
      spectator.send('updateBattle', @id, queue)

    # Now clean-up.
    for id of @queues
      delete @queues[id]

  toString: ->
    "[Battle id:#{@id} turn:#{@turn} weather:#{@weather}]"
