self = (if window? then window.PokeBattle.PBV ?= {} else this)

BATON_PASS_PBV = 15

self.determinePBV = (genData, pokemonArray) ->
  if pokemonArray not instanceof Array then pokemonArray = [ pokemonArray ]
  total = 0
  for pokemon in pokemonArray
    species = pokemon.species
    forme = pokemon.forme || "default"
    item = pokemon.item
    speciesData = genData?.FormeData[species]

    # Handle megas
    mega = genData?.ItemData[item]?.mega
    if mega
      [ megaSpecies, megaForme ] = mega
      if species == megaSpecies
        forme = megaForme

    # Get PBV of the Pokemon's forme
    pbv = speciesData?[forme]?.pokeBattleValue || 0

    # Handle Eviolite
    pbv = Math.round(1.3 * pbv / 5) * 5  if item == 'Eviolite'

    # Add to total
    total += pbv

  # Handle Baton Pass. Baton Pass cray.
  bpers = (p  for p in pokemonArray when "Baton Pass" in (p.moves || []))
  total += BATON_PASS_PBV * Math.pow(2, bpers.length - 1)  if bpers.length > 0

  return total
