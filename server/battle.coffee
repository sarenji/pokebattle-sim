{_} = require 'underscore'
{FakeRNG} = require './rng'
{Pokemon} = require './pokemon'

class @Battle
  # TODO: let Battle serialize these.
  {moves, MoveData, species, PokemonData} = require '../data/bw'
  @pokemon = PokemonData

  constructor: (attributes = {}) ->
    {@players} = attributes

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

    for object in @players
      @objectHash[object.player.id] = object

      # Each object is a hash: {player: socket, team: team}
      # TODO: Make this nicer.
      # Store an "opponents" array for each player. This array contains
      # all players except the current player.
      # This assumes a FFA.
      {player, team} = object
      object.opponents = _.reject @players, (object) ->
        object.player == player

      # Turn every hash in a team into a real, live Pokemon.
      object.team = team.map (attributes) ->
        specimen = species[attributes.name]
        # TODO: Delete check. Validate somewhere else.
        if specimen?
          # TODO: Make nicer.
          attributes.stats = specimen.stats || {}
          attributes.moves = specimen.moves || {}
          attributes.types = specimen.types || []
        new Pokemon(attributes)

  getPlayer: (clientId) =>
    @objectHash[clientId].player

  getTeam: (clientId) =>
    if !@objectHash[clientId]?
      console.log clientId
    @objectHash[clientId].team

  getOpponents: (clientId) =>
    @objectHash[clientId].opponents

  getAction: (clientId) =>
    @playerActions[clientId]

  makeMove: (player, moveName) =>
    moveName = moveName.toLowerCase()
    # TODO: Fail if move not in moves
    # TODO: Fail if move not in player pokemon's moves
    return  if moveName not of MoveData

    # Store the move name that this player wants to make.
    @playerActions[player.id] =
      type: 'move'
      name: moveName

    # End the turn if each player has moved.
    if @hasAllPlayersActed() then @endTurn()

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
    _.any @players, (object) ->
      pokemon = object.team[0]
      pokemon.hasAbility('Air Lock') || pokemon.hasAbility('Cloud Nine')

  # Returns true if all players have moved, false otherwise.
  hasAllPlayersActed: =>
    _.all(@players, (object) => object.player.id of @playerActions)

  # Add `string` to a buffer that will be sent to each client.
  message: (string) =>
    @buffer.push(string)

  clearBuffer: =>
    while @buffer.length > 0
      @buffer.pop()

  endTurn: =>
    # TODO: Sort by priority and active pokemon speed.
    for clientId of @playerActions
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

  performSwitch: (clientId) =>
    player = @getPlayer(clientId)
    action = @getAction(clientId)
    team = @getTeam(clientId)
    @message "#{player.name} withdrew #{team[0].name}!"
    [team[0], team[action.to]] = [team[action.to], team[0]]
    @message "#{player.name} sent out #{team[0].name}!"

  performMove: (clientId) =>
    player = @getPlayer(clientId)
    action = @getAction(clientId)
    pokemon = @getTeam(clientId)[0]
    defenders = @getOpponents(clientId).map (opponent) ->
      opponent.team[0]
    # todo: the move should be cloned and attached to the pokemon
    move = moves[action.name]

    @message "#{player.username}'s #{pokemon.name} used #{move.name}!"

    # TODO: Execute any before move events
    damage = move.execute(this, pokemon, defenders)
    # TODO: Execute any after move events
