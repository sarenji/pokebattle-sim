class @Battle extends Backbone.Model
  initialize: (attributes) =>
    {@socket, @numActive, @index, spectators} = attributes
    @spectators = new UserList(spectators || [])
    @set('notifications', 0)
    @set('turn', 0)

  receiveTeams: (teams) =>
    @teams = []
    for team in teams
      @teams.push @makeTeamFromJSON(team)

  receiveTeam: (team) =>
    @teams[@index].off('all', @_teamEvents)  if @teams[@index]
    @teams[@index] = @makeTeamFromJSON(team)

  makeTeamFromJSON: (json) =>
    pokemon = json.pokemon
    delete json.pokemon
    team = new Team(pokemon, json)
    team.on('all', @_teamEvents)

  _teamEvents: =>
    @trigger.apply(this, arguments)

  makeMove: (moveName, forSlot) =>
    pokemon = @getPokemon(@index, forSlot)
    @socket.send('send move', @id, moveName, forSlot, @get('turn'), pokemon.get('megaEvolve'))
    pokemon.set('megaEvolve', false)

  makeSwitch: (toSlot, forSlot) =>
    @socket.send('send switch', @id, toSlot, forSlot, @get('turn'))

  arrangeTeam: (arrangement) =>
    @socket.send 'arrange team', @id, arrangement

  switch: (fromIndex, toIndex) =>
    you = @getTeam().pokemon
    [you[fromIndex], you[toIndex]] = [you[toIndex], you[fromIndex]]

  getTeam: (playerIndex = @index) =>
    @teams[playerIndex]

  getOpponentTeam: (playerIndex = @index) =>
    @teams[1 - playerIndex]

  getPokemon: (playerIndex, slot = 0) =>
    team = @getTeam(playerIndex)
    team.at(slot)

  # TODO: Opponent switch. Use some logic to determine whether the switch is
  # to a previously seen Pokemon or a new Pokemon. In the latter case, we
  # should reveal a previously unknown Pokeball if it's not a Wi-Fi battle.

  emit: (args...) =>
    @socket(args...)

  notify: =>
    @set('notifications', @get('notifications') + 1)
