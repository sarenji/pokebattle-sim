{_} = require 'underscore'
{FakeRNG} = require './rng'
{Pokemon} = require './pokemon'
{Player} = require './player'
{Team} = require './team'

class @Battle
  # TODO: let Battle serialize these.
  {moves, MoveData, species, PokemonData} = require '../data/bw'

  constructor: (@id, attributes = {}) ->
    @numActive = 1

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
    @weather = "None"

    # Buffer of messages to send to each client.
    @buffer = []

    # Hash of players partaking in the battle.
    @players = {}

    for object in attributes.players
      {player, team} = object
      @players[player.id] = new Player(player, new Team(team, @numActive))

    @beginTurn()

  getPlayer: (id) =>
    @players[id]

  getTeam: (id) =>
    @getPlayer(id).team

  getOpponents: (id) =>
    opponents = []
    for playerId, player of @players
      opponents.push(player)  if id != playerId
    opponents

  getOpponentPokemon: (id, max) =>
    opponents = @getOpponents(id)
    teams = (opponent.team.all()  for opponent in opponents)
    teams = (team.slice(0, max)   for team in teams)  if max?
    _.flatten(teams)

  getActivePokemon: =>
    pokemon = []
    for id, player of @players
      pokemon.push(player.team.getActivePokemon()...)
    pokemon

  getAction: (clientId) =>
    @playerActions[clientId]

  makeMove: (player, moveName) =>
    moveName = moveName.toLowerCase().replace(/\s+/g, '-')
    # TODO: Fail if move not in moves
    # TODO: Fail if move not in player pokemon's moves
    return  if moveName not of MoveData

    # Store the move name that this player wants to make.
    @playerActions[player.id] =
      type: 'move'
      name: moveName

    delete @requests[player.id]

    # End the turn if each player has moved.
    if @areAllRequestsCompleted() then @endTurn()

  # TODO: Test
  makeSwitch: (player, toPokemon) =>
    team = @getTeam(player.id)
    index = team.indexOf(toPokemon)

    # TODO: Fail harder if pokemon not in team
    if index == -1
      console.log "#{player.username} made an invalid switch to #{toPokemon}."
      return

    @switch(player, index)

  switch: (player, toPosition) =>
    # Record the switch
    @playerActions[player.id] =
      type: 'switch'
      to: toPosition

    delete @requests[player.id]

    # End the turn if each player has moved.
    if @areAllRequestsCompleted() then @endTurn()

  hasWeather: (weatherName) =>
    weather = (if @hasWeatherCancelAbilityOnField() then "None" else @weather)
    weatherName == weather

  hasWeatherCancelAbilityOnField: =>
    _.any @getActivePokemon(), (pokemon) ->
      pokemon.hasAbility('Air Lock') || pokemon.hasAbility('Cloud Nine')

  # Returns true if all requests have been completed. False otherwise.
  areAllRequestsCompleted: =>
    requests = 0
    requests += 1  for id of @requests
    requests == 0

  # Add `string` to a buffer that will be sent to each client.
  message: (string) =>
    @buffer.push(string)

  clearBuffer: =>
    while @buffer.length > 0
      @buffer.pop()

  beginTurn: =>
    @turn++

    # Send appropriate requests to players
    for id, player of @players
      poke_moves = player.team.at(0).moves
      switches = player.team.getAlivePokemon().map((p) -> p.name)
      @requestAction(player, moves: poke_moves, switches: switches)

  requestAction: (player, validActions) =>
    @requests[player.id] = validActions
    player.requestAction(@id, validActions)

  endTurn: =>
    for id in @orderIds()
      action = @getAction(id)
      player = @getPlayer(id)
      team = @getTeam(id)
      switch action.type
        when 'switch' then @performSwitch(id)
        when 'move'   then @performMove(id)

      # Clean up playerActions hash.
      delete @playerActions[id]

      @requestFaintedReplacements()

    if @requestQueue.length > 0
      top = @requestQueue.shift()
      {player, validActions} = top
      @requestAction(player, validActions)

    # Send a message to each player.
    @message 'The turn ticked.'
    for id, player of @players
      player.updateChat('SERVER', @buffer.join("<br>"))
    @clearBuffer()

    if @areAllRequestsCompleted() then @beginTurn()

  # If a Pokemon faints, add the player to the action queue.
  requestFaintedReplacements: =>
    for id, player of @players
      team = player.team
      active = team.getActivePokemon()
      if _.any(active, (p) -> p.isFainted())
        validActions = {switches: team.getAliveBenchedPokemon()}
        @requestQueue.push({player, validActions})

  orderIds: =>
    ids = (id  for id of @playerActions)
    ordered = []
    for id in ids
      action = @getAction(id)
      priority = @actionPriority(action)
      pokemon = @getTeam(id).at(0)
      ordered.push({id, priority, pokemon})
    ordered.sort(@orderComparator)
    ordered.map((o) -> o.id)

  orderComparator: (a, b) =>
    diff = b.priority - a.priority
    if diff == 0
      diff = b.pokemon.stat('speed') - a.pokemon.stat('speed')
      if diff == 0
        diff = (if @rng.next() < .5 then -1 else 1)
    diff

  actionPriority: (action) =>
    switch action.type
      when 'switch' then 5
      # TODO: Apply priority callbacks
      when 'move'   then MoveData[action.name].priority

  performSwitch: (id) =>
    player = @getPlayer(id)
    action = @getAction(id)
    team = @getTeam(id)
    @message "#{player.username} withdrew #{team.at(0).name}!"
    team.switch(0, action.to)
    @message "#{player.username} sent out #{team.at(0).name}!"
    # TODO: Hacky.
    player.emit? 'switch pokemon', 0, action.to

  performMove: (id) =>
    player = @getPlayer(id)
    action = @getAction(id)
    pokemon = @getTeam(id).at(0)
    defenders = @getOpponentPokemon(id, @numActive)
    # todo: the move should be cloned and attached to the pokemon
    move = moves[action.name]

    @message "#{player.username}'s #{pokemon.name} used #{move.name}!"

    # TODO: Execute any before move events
    damage = move.execute(this, pokemon, defenders)
    # TODO: Execute any after move events
