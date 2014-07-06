class TeamStore extends Backbone.Collection
  model: Team

  initialize: ->
    @on('add remove reset saving saved', @saveLocally)
    @loadLocally()

  unsavedTeams: =>
    @filter((team) -> !team.id)

  # Only locally save teams without an id.
  saveLocally: =>
    teams = @unsavedTeams()
    json = _.map(teams, (team) -> team.toJSON())
    try
      window.localStorage.setItem('local_teams', JSON.stringify(json))
    catch
      console.error("Failed to save teams locally.")

  loadLocally: =>
    try
      json = window.localStorage.getItem('local_teams')
      return  unless json
      teams = JSON.parse(json)
      @add(teams)  if teams.length > 0
    catch
      console.error("Failed to load teams locally.")

  saveRemotely: =>
    teams = @unsavedTeams()
    team.save()  for team in teams

PokeBattle.TeamStore = new TeamStore()

PokeBattle.primus.on 'receiveTeams', (remoteTeams) ->
  remoteTeams = remoteTeams.map (team) ->
    team.teambuilder = true
    new Team(team)

  # First, find teams that are already saved locally -- these exclude deleted
  # teams on either side. The remote copy of the team is checked against the
  # local copy of the team. If they differ, display a modal asking whether to
  # override or keep the local changes.
  ids = PokeBattle.TeamStore.pluck('id')
  for remoteTeam in remoteTeams when remoteTeam.id in ids
    remoteJSON = remoteTeam.toJSON()
    localTeam = PokeBattle.TeamStore.get(remoteTeam.id)
    unsavedTeam = localTeam.clone()
    unsavedTeam.set(localTeam.previousAttributes(), silent: true)
    localJSON = unsavedTeam.toJSON()
    if !_.isEqual(remoteJSON, localJSON)
      # Whoa! Versions are different! Let's ask the user what to do.
      teamText = PokeBattle.exportTeam(remoteJSON.pokemon)
      domId = "teams-differ-#{remoteTeam.id}"
      $modal = PokeBattle.modal('modals/teams_differ', domId, {teamText})
      $modal.find('textarea').first().focus()
      do (localTeam, remoteJSON) ->
        # We want to override the current version with the one on the server.
        # This is extremely hacky due to hidden state and clones everywhere on
        # the teambuilder.
        $modal.find('.button_override').one 'click', ->
          localTeam.set(remoteJSON, silent: true)
          localTeam.trigger('render', localTeam)
          $modal.modal('hide')

  # Now, add teams we haven't seen yet to the store.
  PokeBattle.TeamStore.add(remoteTeams)

PokeBattle.primus.on 'loginSuccess', ->
  PokeBattle.primus.send('requestTeams')
