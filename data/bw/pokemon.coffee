{Specimen} = require '../../server/species'

@species = {}

json_url = if process.env.NODE_ENV == 'test'
  '../../test/data/bw/data_pokemon.json'
else
  './data_pokemon.json'

@PokemonData = require(json_url)
for name, attributes of @PokemonData
  @species[name] = new Specimen(attributes)
