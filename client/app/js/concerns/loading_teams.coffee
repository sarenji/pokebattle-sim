PokeBattle.loadTeams = (teambuilderview=true) ->
  teamsJSON = window.localStorage.getItem("teams")
  if teamsJSON
    teamsJSON = JSON.parse(teamsJSON)
    for teamJSON in teamsJSON
      pokemonJSON.teambuilder = true for pokemonJSON in teamJSON.pokemon
    teams = teamsJSON.map(PokeBattle.jsonToTeam)
  return teams

PokeBattle.jsonToTeam = (json) ->
  {pokemon} = json
  p.teambuilder = true  for p in pokemon
  attributes = _.clone(json)
  delete attributes.pokemon
  return new Team(pokemon, attributes)