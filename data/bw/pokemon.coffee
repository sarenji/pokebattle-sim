{Specimen} = require '../../server/species'

@species = {}

@PokemonData = require('./pokemon.yml')
for name, attributes of @PokemonData
  @species[name] = new Specimen(attributes)
