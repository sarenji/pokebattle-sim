HiddenPower = (if module? then require('../../../../shared/hidden_power') else window.HiddenPower ?= {})

@PokeBattle ?= {}
@PokeBattle.parseTeam = (teamString) ->
  text = teamString.split('\n')
  team = []
  pokemonRegex = /^(.*?)\s*(\(M\)|\(F\)|)?(?:\s*@\s*(.*))?$/
  pokemon = null
  for line in text
    line = line.trim()
    if line.length == 0
      pokemon = null
    else if !pokemon
      [ all, pokemonLine, gender, item ] = line.match(pokemonRegex)
      pokemon = {}
      team.push(pokemon)

      # Ignore nicknames for now
      pokemonLine    = RegExp.$1  if pokemonLine.match(/.*?\s*\((.*)\)/)
      convertNameToSpeciesAndForme(pokemon, pokemonLine.trim())
      pokemon.gender = gender[1]  if gender  # (M) and (F)
      pokemon.item   = item    if item
    else if line.match(/^(?:Trait|Ability):\s+(.*)$/i)
      pokemon.ability = RegExp.$1
    else if line.match(/^Level:\s+(.*)$/i)
      pokemon.level = Number(RegExp.$1) || 100
    else if line.match(/^Happiness:\s+(.*)$/i)
      pokemon.happiness = Number(RegExp.$1) || 0
    else if line.match(/^Shiny: Yes$/i)
      pokemon.shiny = true
    else if line.match(/^EVs: (.*)$/i)
      evs = RegExp.$1.split(/\//g)
      pokemon.evs = {}
      for ev in evs
        ev = ev.trim()
        [ numberString, rawStat ] = ev.split(/\s+/)
        pokemon.evs[statsHash[rawStat]] = Number(numberString) || 0
    else if line.match(/^IVs: (.*)$/i)
      ivs = RegExp.$1.split(/\//g)
      pokemon.ivs = {}
      for iv in ivs
        iv = iv.trim()
        [ numberString, rawStat ] = iv.split(/\s+/)
        pokemon.ivs[statsHash[rawStat]] = Number(numberString) || 0
    else if line.match(/^([A-Za-z]+) nature/i)
      pokemon.nature = RegExp.$1
    else if line.match(/^[\-\~]\s*(.*)/)
      moveName = RegExp.$1
      if /Hidden Power \[/.test(moveName)
        if !pokemon.ivs
          moveName.match(/Hidden Power \[\s*(.*)\s*\]/i)
          hiddenPowerType = RegExp.$1.toLowerCase()
          pokemon.ivs = HiddenPower.BW.ivs[hiddenPowerType] || {}
        moveName = 'Hidden Power'
      pokemon.moves ?= []
      pokemon.moves.push(moveName)
  return team

statsHash =
  'HP'   : 'hp'
  'Atk'  : 'attack'
  'Def'  : 'defense'
  'SAtk' : 'specialAttack'
  'SDef' : 'specialDefense'
  'Spe'  : 'speed'

convertNameToSpeciesAndForme = (pokemon, name) ->
  if name.match(/(.*)-T(herian)?/i)
    pokemon.name = RegExp.$1
    pokemon.forme = 'therian'
  else if name.match(/Shaymin-S(ky)?/i)
    pokemon.name = "Shaymin"
    pokemon.forme = 'sky'
  else if name.match(/Giratina-O(rigin)?/i)
    pokemon.name = "Giratina"
    pokemon.forme = 'origin'
  else if name.match(/Arceus(\-.*)?/)
    pokemon.name = "Arceus"
  else if name.match(/Kyurem-B(lack)?/)
    pokemon.name = "Kyurem"
    pokemon.forme = "black"
  else if name.match(/Kyurem-W(hite)?/)
    pokemon.name = "Kyurem"
    pokemon.forme = "white"
  else if name.match(/Rotom-W|Rotom-Wash/)
    pokemon.name = "Rotom"
    pokemon.forme = "wash"
  else if name.match(/Rotom-S|Rotom-Fan/)
    pokemon.name = "Rotom"
    pokemon.forme = "fan"
  else if name.match(/Rotom-H|Rotom-Heat/)
    pokemon.name = "Rotom"
    pokemon.forme = "heat"
  else if name.match(/Rotom-F|Rotom-Frost/)
    pokemon.name = "Rotom"
    pokemon.forme = "frost"
  else if name.match(/Rotom-C|Rotom-Mow/)
    pokemon.name = "Rotom"
    pokemon.forme = "mow"
  else if name.match(/Deoxys-A|Deoxys-Attack/)
    pokemon.name = "Deoxys"
    pokemon.forme = "attack"
  else if name.match(/Deoxys-D|Deoxys-Defense/)
    pokemon.name = "Deoxys"
    pokemon.forme = "defense"
  else if name.match(/Deoxys-S|Deoxys-Speed/)
    pokemon.name = "Deoxys"
    pokemon.forme = "speed"
  else
    pokemon.name = name
