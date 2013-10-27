{SupportedGenerations} = require('../shared/ladders')

@GenerationJSON = {}

for gen in SupportedGenerations
  {SpeciesData, FormeData, MoveData, ItemData} = require("./#{gen}/data")
  @GenerationJSON[gen.toUpperCase()] = {SpeciesData, FormeData, MoveData, ItemData}
