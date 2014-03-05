class @Battle extends Backbone.Model
  initialize: (attributes) =>
    {@socket, @numActive, @index, spectators} = attributes
    @spectators = new UserList(spectators || [])
    @set('notifications', 0)
    @set('turn', 0)

  receiveTeams: (teams) =>
    @teams ?= []
    for team, i in teams
      @teams[i] = @makeTeamFromJSON(team)

  receiveTeam: (team) =>
    @teams ?= []
    @teams[@index].pokemon.off('all', @_teamEvents)  if @teams[@index]
    @teams[@index] = @makeTeamFromJSON(team)

  makeTeamFromJSON: (json) =>
    team = new Team(json)
    team.pokemon.on('all', @_teamEvents)
    team

  _teamEvents: =>
    @trigger.apply(this, arguments)

  makeMove: (moveName, forSlot) =>
    pokemon = @getPokemon(@index, forSlot)
    @socket.send('sendMove', @id, moveName, forSlot, @get('turn'), pokemon.get('megaEvolve'))
    pokemon.set('megaEvolve', false)

  makeSwitch: (toSlot, forSlot) =>
    @socket.send('sendSwitch', @id, toSlot, forSlot, @get('turn'))

  makeCancel: =>
    @socket.send 'sendCancelAction', @id, @get('turn')

  arrangeTeam: (arrangement) =>
    @socket.send 'arrangeTeam', @id, arrangement

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
