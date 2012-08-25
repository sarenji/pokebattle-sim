{Specimen} = require '../../server/species'

@species = {}

yaml_url = if process.env.NODE_ENV == 'test'
  '../../test/data/bw/pokemon.yml'
else
  './pokemon.yml'

@PokemonData = require(yaml_url)
for name, attributes of @PokemonData
  @species[name] = new Specimen(attributes)
