self = (if window? then window.PokeBattle.PBV ?= {} else this)

self.determinePBV = (genData, pokemonArray) ->
  if pokemonArray not instanceof Array then pokemonArray = [ pokemonArray ]
  total = 0
  for pokemon in pokemonArray
    species = pokemon.name
    forme = pokemon.forme || "default"
    item = pokemon.item
    speciesData = genData?.FormeData[species]

    # Handle megas
    mega = genData?.ItemData[item]?.mega
    if mega
      [ megaSpecies, megaForme ] = mega
      if species == megaSpecies
        forme = megaForme

    # Add to total
    total += speciesData?[forme]?.pokeBattleValue || 0
  return total
