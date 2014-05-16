class Teams extends Backbone.Collection
  model: Team

class @Battle extends Backbone.AssociatedModel
  relations: [
    type: Backbone.Many
    key:  'teams'
    relatedModel: Team
    collectionType: Teams
  ]

  initialize: (attributes) =>
    {@socket, @numActive, @index, spectators} = attributes
    @spectators = new UserList(spectators || [])
    @set('notifications', 0)
    @set('turn', 0)
    @set('teams', [{hidden: true}, {hidden: true}])

  receiveTeams: (receivedTeams) =>
    teams = @get('teams')
    for receivedTeam, i in receivedTeams
      receivedTeam.hidden = true
      team = teams.at(i)
      team.set(receivedTeam)  if team.get('hidden')

  receiveTeam: (team) =>
    teams = @get('teams')
    teams.at(@index).unset('hidden', silent: true).set(team)

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
    @get("teams").at(playerIndex)

  getOpponentTeam: (playerIndex = @index) =>
    @get("teams").at(1 - playerIndex)

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
