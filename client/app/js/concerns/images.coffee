@PokemonIconBackground = (name) ->
  id  = PokemonData[name].id
  x   = (id % 16) * 32
  y   = (id >> 4) * 32
  "background-position: -#{x}px -#{y}px"
