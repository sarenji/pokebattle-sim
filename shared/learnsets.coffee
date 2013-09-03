self = (module?.exports || window)

unportableGenerations = [ 1, 3 ]
unportableGenerations.sort((a, b) -> b - a)  # numeric, descending

getMinimumGeneration = (generation) ->
  for unportableGen in unportableGenerations
    if unportableGen <= generation
      return unportableGen
  minGeneration = Math.min(unportableGenerations...)
  throw new Error("Gen. '#{generation}' must be greater than #{minGeneration}.")

# Loop through the learnsets for this pokemon and all prevolutions.
# This takes all available generations into count.
loopLearnsets = (forGeneration, SpeciesData, FormeData, pokemon, iterator) ->
  minimumGeneration = getMinimumGeneration(forGeneration)
  [name, formeName] = [pokemon.name, pokemon.forme]
  # Loop through formes
  while name
    forme = FormeData[name][formeName]
    # Loop through all available generations
    for generation in [minimumGeneration..forGeneration]
      learnset = forme.learnset["generation-#{generation}"]
      # Skip if this Pokemon has no learnset for this generation.
      continue  if !learnset
      if iterator(learnset) == true then return true
    name = SpeciesData[name].evolvedFrom
  return false

# Returns an array of moves that this Pokemon can learn for a given generation.
self.learnableMoves = (pokemon, forGeneration) ->

self.checkMoveset = (SpeciesData, FormeData, pokemon, forGeneration, moves) ->
  leftoverMoves = []
  for move in moves
    if !self.checkMove(SpeciesData, FormeData, pokemon, forGeneration, move)
      leftoverMoves.push(move)

  # This Pokemon can learn all moves through level-up, tutoring, or machines.
  return true  if leftoverMoves.length == 0

  standardGroups = [ "level-up", "tutor", "machine", "egg" ]

  # There are certain ways specific Pokemon can learn a move.
  # Check non-standard groups:
  # "form-change", "light-ball-egg", "stadium-surfing-pikachu"
  return true  if loopLearnsets forGeneration, SpeciesData, FormeData, pokemon, (learnset) ->
    # Check to see if special moves can completely overlap these moves
    learnsetGroups = (g  for g of learnset when g not in standardGroups)
    for groupName in learnsetGroups
      total = 0
      for move in leftoverMoves
        total += (if move of learnset[groupName] then 1 else 0)

      # If one group completely overlaps the leftover moves, we're good.
      return true  if total == leftoverMoves.length

  # TODO: Check chain-breeding.
  eggMoves = []
  loopLearnsets forGeneration, SpeciesData, FormeData, pokemon, (learnset) ->
    return  if !learnset['egg']
    for moveName of learnset['egg']
      continue  if moveName in eggMoves || moveName not in leftoverMoves
      eggMoves.push(moveName)
  return true  if eggMoves.length == leftoverMoves.length

  return false

self.checkMove = (SpeciesData, FormeData, pokemon, forGeneration, move) ->
  {level} = pokemon
  valid = false

  return true  if loopLearnsets forGeneration, SpeciesData, FormeData, pokemon, (learnset) ->
    # Check level-up, TM/HM, and tutors.
    return true  if learnset["level-up"]?[move] <= level ||
                     learnset["machine"]?[move]  <= level ||
                     learnset["tutor"]?[move]    <= level

    # If the Pokemon can learn Sketch, then by golly, it can learn anything!
    # ... Except Chatter and Struggle. NOTE: Bogus moves are considered valid,
    # so you must take care of them at a higher level.
    return true  if learnset["level-up"]?["Sketch"] <= level &&
                     move not in [ "Chatter", "Struggle" ]

  # TODO: Skip unavailable Pokemon (due to being a generation later).
  # TODO: level-up moves can be bred.
  return false
