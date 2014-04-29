class TeamStore extends Backbone.Collection
  model: Team

  initialize: (models, options) ->

  sync: ->
    teams = @getTeams()
    @reset(teams)

  # Moves a team with the given id to the new index, and persist
  # the change.
  moveTeam: (id, newIndex) ->
    team = @get(id)
    @remove(id)
    @add(team, at: newIndex)
    @setTeams(@models)


  #####################################################
  # NOTE: These following methods are not part of the official interface,
  #       and are used to transition to saving teams on the server
  #####################################################
  
  getTeams: (options) ->
    teamJSON = _(JSON.parse(window.localStorage.getItem('teams')))
    teams = teamJSON.map((json) -> new Team(json, teambuilder: true))

    # backwards compatibility: Assign an id to teams that don't have one, if any
    maxId = _(teams).max((team) -> team.id)?.id || 0
    teamUpdated = false
    for team in teams
      if team.isNew()
        teamUpdated = true
        team.id = maxId + 1
        maxId = team.id

    @setTeams(teams)  if teamUpdated

    return teams

  saveTeam: (team) ->
    currentTeams = @getTeams()

    if not team.isNew()
       # find the index of this team in the teams array and replace it
      idx = @getIndexOfTeamInList(currentTeams, team)

      if idx != -1
        currentTeams[idx] = team  # replace the team
      else
        team.id = null  # the team must have been deleted in a different tab

    if team.isNew()
      newId = (_(currentTeams).max((team) -> team.id)?.id || 0) + 1
      team.id = newId
      currentTeams.push(team)

    @setTeams(currentTeams)

  destroyTeam: (team) ->
    currentTeams = @getTeams()
    idx = @getIndexOfTeamInList(currentTeams, team)
    currentTeams.splice(idx, 1)  if idx > -1

    @setTeams(currentTeams)

  getIndexOfTeamInList: (listOfTeams, team) ->
    idx = -1
    for currentTeam, i in listOfTeams
      if currentTeam.id == team.id
        idx = i
        break
    return idx

  setTeams: (teams) ->
    teamJSON = teams.map((team) -> team.toJSON())
    window.localStorage.setItem('teams', JSON.stringify(teamJSON))
    @reset(teams)

PokeBattle.TeamStore = new TeamStore()
PokeBattle.TeamStore.fetch()
