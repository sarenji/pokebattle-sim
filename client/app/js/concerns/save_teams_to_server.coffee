# One-off script for people to automatically save their localStorage teams
# to the server, so they don't have to re-upload.
PokeBattle.events.once 'loginSuccess', ->
  try
    storage = window.localStorage.getItem('teams')
    if storage
      teamsJSON = JSON.parse(storage)
      for teamJSON in teamsJSON
        delete teamJSON.id
        team = new Team(teamJSON)
        PokeBattle.TeamStore.add(team)
        team.save()
      window.localStorage.removeItem('teams')
  catch
    console.error("Tried to load teams, but couldn't!")
