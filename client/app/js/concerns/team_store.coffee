jsonToTeam = (json, options={}) =>
  {pokemon} = json
  p.teambuilder = true  for p in pokemon
  attributes = _.clone(json)
  attributes.teambuilder = true  if options.teambuilder
  delete attributes.pokemon
  return new Team(pokemon, attributes)

class TeamStore
  constructor: ->

  saveTeam: (team) ->

  getTeam: (idx) ->
    team = @getTeams()[idx]

  getTeams: (options) ->
    _(JSON.parse(window.localStorage.getItem('teams'))).map((json) -> jsonToTeam(json, options))

  getSelectedTeam: ->
    selectedIndex = @getSelectedTeamIndex() || 0
    @getTeam(selectedIndex) || getTeam(0)

  # Set the index of the selected team:
  # NOTE: We may eventually want to substitute selected team indices for a global team id
  setSelectedTeamIndex: (idx) ->
    window.localStorage.setItem('selectedTeamIndex', idx)

  getSelectedTeamIndex: () ->
    window.localStorage.getItem('selectedTeamIndex')

  getTeamCount: ->
    @getTeams().length

PokeBattle.TeamStore = new TeamStore()