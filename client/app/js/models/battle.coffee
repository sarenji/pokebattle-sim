class Teams extends Backbone.Collection
  model: Team

class @Battle extends Backbone.AssociatedModel
  relations: [
    type: Backbone.Many
    key:  'teams'
    relatedModel: Team
    collectionType: Teams
  ]

  defaults:
    spectating: true
    finished: false

  initialize: (attributes) =>
    {@numActive, @index, spectators} = attributes
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

  makeMove: (moveName, forSlot, callback) =>
    pokemon = @getPokemon(@index, forSlot)
    options = {}
    options['megaEvolve'] = pokemon.get('megaEvolve')  if pokemon.get('megaEvolve')
    PokeBattle.primus.send(
      'sendMove', @id, moveName, forSlot,
      @get('turn'), options, callback,
    )

  makeSwitch: (toSlot, forSlot, callback) =>
    PokeBattle.primus.send(
      'sendSwitch', @id, toSlot, forSlot, @get('turn'), callback
    )

  makeCancel: =>
    PokeBattle.primus.send 'sendCancelAction', @id, @get('turn')

  arrangeTeam: (arrangement) =>
    PokeBattle.primus.send 'arrangeTeam', @id, arrangement

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

  isPlaying: =>
    !@get('finished') && !@get('spectating')

  forfeit: =>
    PokeBattle.primus.send('forfeit', @id)

  # TODO: Opponent switch. Use some logic to determine whether the switch is
  # to a previously seen Pokemon or a new Pokemon. In the latter case, we
  # should reveal a previously unknown Pokeball if it's not a Wi-Fi battle.

  notify: =>
    @set('notifications', @get('notifications') + 1)
