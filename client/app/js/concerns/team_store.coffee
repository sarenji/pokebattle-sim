class TeamStore extends Backbone.Collection
  model: Team

PokeBattle.TeamStore = new TeamStore()

PokeBattle.socket.addEvents
  receiveTeams: (socket, teams) ->
    PokeBattle.TeamStore.reset(teams)

  teamSaved: (socket, cid, teamId) ->
    team = PokeBattle.TeamStore.get(cid)
    if !team
      console.error("Could not find team #{cid}")
    else
      team.set('id', teamId)

PokeBattle.events.on 'loginSuccess', ->
  PokeBattle.socket.send('requestTeams')
