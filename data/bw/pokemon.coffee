{Specimen} = require '../../server/species'

@Species = {}

json_url = './data_pokemon.json'

@PokemonData = require(json_url)
for name, attributes of @PokemonData
  @Species[name] = new Specimen(attributes)
