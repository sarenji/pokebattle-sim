self = (module?.exports || window)

unportableGenerations = [ 1, 3 ]
unportableGenerations.sort((a, b) -> b - a)  # numeric, descending

switchableFormes = [
  "Deoxys"
  "Rotom"
  "Shaymin"
]

getMinimumGeneration = (generation) ->
  for unportableGen in unportableGenerations
    if unportableGen <= generation
      return unportableGen
  minGeneration = Math.min(unportableGenerations...)
  throw new Error("Gen. '#{generation}' must be greater than #{minGeneration}.")

# A helper method to loop through the learnsets for this pokemon and all
# prevolutions, and then runs an iterator function (that you give) on those
# learnsets. The iterator function takes one parameter, `learnset`, the learnset
# for a given generation for the Pokemon's current forme.
#
# All generations that can be used are taken into consideration.
loopLearnsets = (SpeciesData, FormeData, pokemon, forGeneration, iterator) ->
  minimumGeneration = getMinimumGeneration(forGeneration)
  [name, formeName] = [pokemon.name, pokemon.forme]
  # Find pre-evolutions and formes
  thePokemon = []
  theFormes = [ formeName ]
  while name
    thePokemon.push(name)
    if name in switchableFormes && name not in theFormes
      theFormes.push((forme  for forme of FormeData[name])...)
    name = SpeciesData[name].evolvedFrom

  # Loop through pre-evolutions and formes
  for name in thePokemon
    for formeName in theFormes
      forme = FormeData[name][formeName]
      # Loop through all available generations
      for generation in [minimumGeneration..forGeneration]
        learnset = forme.learnset["generation-#{generation}"]
        # Skip if this Pokemon has no learnset for this generation.
        continue  if !learnset
        if iterator(learnset) == true then return true
  return false

# Returns an array of moves that this Pokemon can learn for a given generation.
self.learnableMoves = (pokemon, forGeneration) ->

# Checks the moveset of a given Pokemon for a given generation, with the given
# species and forme data for all Pokemon.
#
# Returns true if the moveset is valid, false otherwise.
self.checkMoveset = (SpeciesData, FormeData, pokemon, generation, moves) ->
  looper = loopLearnsets.bind(null, SpeciesData, FormeData, pokemon, generation)

  # If the moveset does not contain all the moves inside the `form-change`
  # learnset for the given generation, the moveset is invalid.
  forme = FormeData[pokemon.name][pokemon.forme]
  learnset = forme.learnset["generation-#{generation}"]?['form-change']
  for move, level of learnset
    return false  if move not in moves || pokemon.level < level

  # Get a list of all moves that the Pokemon can't learn
  # through level-up, tutoring, machines, or Sketch.
  leftoverMoves = (m  for m in moves when !checkMove(looper, pokemon, m))

  # If there are no leftover moves, then we're done, the moveset is valid.
  return true  if leftoverMoves.length == 0

  # Each Pokemon has certain learnset groups. Standard ones are listed below.
  standardGroups = [ "level-up", "tutor", "machine", "egg" ]

  # Check non-standard groups:
  # "form-change", "light-ball-egg", "stadium-surfing-pikachu"
  return true  if looper (learnset) ->
    nonstandardGroups = (g  for g of learnset when g not in standardGroups)
    # If a non-standard group completely overlaps the leftover moves, the
    # moveset is valid.
    for group in nonstandardGroups
      total = (m  for m in leftoverMoves when m of learnset[group]).length
      return true  if total == leftoverMoves.length

  # This makes it so if the remaining moves are all egg moves, the moveset is
  # valid. That's false, but it's permissive. Later, factor in chain-breeding.
  # TODO: Check chain-breeding.
  eggMoves = []
  looper (learnset) ->
    return  if !learnset['egg']
    for moveName of learnset['egg']
      continue  if moveName in eggMoves || moveName not in leftoverMoves
      eggMoves.push(moveName)
  return true  if eggMoves.length == leftoverMoves.length

  return false

# Checks a single move to see if the Pokemon can learn it through level-up,
# tutors, machines, Sketch, or pre-evolutions.
checkMove = (looper, pokemon, move) ->
  {level} = pokemon

  return true  if looper (learnset) ->
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
