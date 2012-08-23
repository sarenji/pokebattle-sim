{Specimen} = require '../../server/species'

@species = {}

@PokemonData = require('./pokemon.yml').pop()
for name, attributes of @PokemonData
  @species[name] = new Specimen(attributes)
