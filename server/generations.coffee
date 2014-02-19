{_} = require('underscore')
learnsets = require '../shared/learnsets'

@ALL_GENERATIONS = [ 'rb', 'gs', 'rs', 'dp', 'bw', 'xy' ]
@SUPPORTED_GENERATIONS = [ 'bw', 'xy' ]
@DEFAULT_GENERATION = 'xy'

@INT_TO_GENERATION = {}
for gen, i in @ALL_GENERATIONS
  @INT_TO_GENERATION[i + 1] = gen

@GENERATION_TO_INT = {}
for gen, i in @ALL_GENERATIONS
  @GENERATION_TO_INT[gen] = (i + 1)

@GenerationJSON = {}

# TODO: Get rid of this once we have all data in.
maybeRequire = (path) ->
  try
    require(path)

for gen in @ALL_GENERATIONS
  SpeciesData = maybeRequire("./#{gen}/data/data_species.json") || {}
  FormeData   = maybeRequire("./#{gen}/data/data_formes.json") || {}
  MoveData    = maybeRequire("./#{gen}/data/data_moves.json")  || {}
  ItemData    = maybeRequire("./#{gen}/data/data_items.json")  || {}
  AbilityData = maybeRequire("./#{gen}/data/data_abilities.json")  || {}
  PokemonList = (name  for name of FormeData)
  ItemList    = (name  for name of ItemData)
  MoveList    = []
  TypeList    = []
  AbilityList = []
  MoveMap     = {}
  AbilityMap  = {}
  TypeMap     = {}

  for pokemonName, pokemonData of FormeData
    for formeName, formeData of pokemonData
      # Add types
      for type in formeData.types
        TypeList.push(type)
        TypeMap[type] ?= []
        TypeMap[type].push([pokemonName, formeName])

      # Add abilities
      abilities = []
      abilities.push(formeData.abilities...)
      abilities.push(formeData.hiddenAbility)  if formeData.hiddenAbility
      for ability in abilities
        AbilityMap[ability] ?= []
        AbilityMap[ability].push([pokemonName, formeName])

  AbilityList = Object.keys(AbilityData)
  MoveList    = Object.keys(MoveData)
  TypeList    = _.chain(TypeList).uniq().sort().value()

  @GenerationJSON[gen.toUpperCase()] =
    SpeciesData : SpeciesData
    FormeData   : FormeData
    MoveData    : MoveData
    ItemData    : ItemData
    AbilityData : AbilityData
    PokemonList : PokemonList
    ItemList    : ItemList
    MoveList    : MoveList
    AbilityList : AbilityList
    TypeList    : TypeList
    MoveMap     : MoveMap
    AbilityMap  : AbilityMap
    TypeMap     : TypeMap

# Now add moves for every generation
for gen in @ALL_GENERATIONS
  thisGen = @GenerationJSON[gen.toUpperCase()]
  for pokemonName, pokemonData of thisGen.FormeData
    for formeName, formeData of pokemonData
      pokemon = {name: pokemonName, forme: formeName}

      # Add moves
      moves = learnsets.learnableMoves(@GenerationJSON, pokemon, @GENERATION_TO_INT[gen])

      for moveName in moves
        thisGen.MoveMap[moveName] ?= []
        thisGen.MoveMap[moveName].push([pokemonName, formeName])
