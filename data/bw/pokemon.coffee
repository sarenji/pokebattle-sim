{Specimen} = require '../../server/species'

@species = {}

json_url = './data_pokemon.json'

@PokemonData = require(json_url)
for name, attributes of @PokemonData
  @species[name] = new Specimen(attributes)
