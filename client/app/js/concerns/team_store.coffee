class TeamStore extends Backbone.Collection
  model: Team

PokeBattle.TeamStore = new TeamStore()

PokeBattle.socket.addEvents
  receiveTeams: (socket, remoteTeams) ->
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
      localJSON = new Team(localTeam.previousAttributes()).toJSON()
      if !_.isEqual(remoteJSON, localJSON)
        # Whoa! Versions are different! Let's ask the user what to do.
        teamText = PokeBattle.exportTeam(remoteJSON.pokemon)
        domId = "teams-differ-#{remoteTeam.id}"
        $modal = $("##{domId}")
        if $modal.length == 0
          $modal = $(JST['modals/teams_differ']({teamText}))
          $modal.prop('id', domId).appendTo($('body'))
        $modal.modal('show')
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

  teamSaved: (socket, cid, teamId) ->
    team = PokeBattle.TeamStore.get(cid)
    if !team
      console.error("Could not find team #{cid}")
    else
      team.set('id', teamId)

PokeBattle.events.on 'loginSuccess', ->
  PokeBattle.socket.send('requestTeams')
