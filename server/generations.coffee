ladders = require('../shared/ladders')

@GenerationJSON = {}

for gen in ladders.ALL_GENERATIONS
  {SpeciesData, FormeData, MoveData, ItemData} = require("./#{gen}/data")
  @GenerationJSON[gen.toUpperCase()] = {SpeciesData, FormeData, MoveData, ItemData}
