class @Battle extends Backbone.Model
  initialize: (attributes) =>
    {@socket, @numActive, @index, @teams} = attributes

  makeMove: (moveName) =>
    @socket.send 'send move', @id, moveName

  makeSwitch: (toSlot) =>
    @socket.send 'send switch', @id, toSlot

  switch: (fromIndex, toIndex) =>
    you = @getTeam()
    [you[fromIndex], you[toIndex]] = [you[toIndex], you[fromIndex]]

  getTeam: (playerIndex = @index) =>
    @teams[playerIndex].pokemon

  getOpponentTeam: (playerIndex = @index) =>
    for team, i in @teams
      return team.pokemon  if i != playerIndex
    return null

  getPokemon: (playerIndex, slot) =>
    team = @getTeam(playerIndex)
    team[slot]

  # TODO: Opponent switch. Use some logic to determine whether the switch is
  # to a previously seen Pokemon or a new Pokemon. In the latter case, we
  # should reveal a previously unknown Pokeball if it's not a Wi-Fi battle.

  emit: (args...) =>
    @socket(args...)
