{_} = require 'underscore'
{FakeRNG} = require './rng'
{Pokemon} = require './pokemon'
{Player} = require './player'
{Team} = require './team'

class @Battle
  # TODO: let Battle serialize these.
  {moves, MoveData, species, PokemonData} = require '../data/bw'

  constructor: (attributes = {}) ->
    @numActive = 1

    # Stores the current turn of the battle
    @turn = 0

    # Stores the actions each player is about to make
    # Keyed by player.id
    @playerActions = {}

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

    # End the turn if each player has moved.
    if @hasAllPlayersActed() then @endTurn()

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

    # End the turn if each player has moved.
    if @hasAllPlayersActed() then @endTurn()

  hasWeather: (weatherName) =>
    weather = (if @hasWeatherCancelAbilityOnField() then "None" else @weather)
    weatherName == weather

  hasWeatherCancelAbilityOnField: =>
    _.any @getActivePokemon(), (pokemon) ->
      pokemon.hasAbility('Air Lock') || pokemon.hasAbility('Cloud Nine')

  # Returns true if all players have moved, false otherwise.
  hasAllPlayersActed: =>
    ids = (id  for id of @players)
    _.all(ids, (id) => id of @playerActions)

  # Add `string` to a buffer that will be sent to each client.
  message: (string) =>
    @buffer.push(string)

  clearBuffer: =>
    while @buffer.length > 0
      @buffer.pop()

  endTurn: =>
    for clientId in @orderIds()
      action = @getAction(clientId)
      switch action.type
        when 'switch' then @performSwitch(clientId)
        when 'move'   then @performMove(clientId)

      # Clean up playerActions hash.
      delete @playerActions[clientId]

    # Send a message to each player about the end of turn.
    @message 'end turn!'
    for object in @players
      object.player.emit? 'updatechat', 'SERVER', @buffer.join("<br>")
    @clearBuffer()

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
