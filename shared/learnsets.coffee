self = (module?.exports || window)

if module?.exports
  EventPokemon = require('./event_pokemon')
  {INT_TO_GENERATION} = require('./ladders')
  {_} = require('underscore')
else
  EventPokemon = window.EventPokemon ? {}
  INT_TO_GENERATION = window.INT_TO_GENERATION
  _ = window._

unportableGenerations = [ 1, 3 ]
unportableGenerations.sort((a, b) -> b - a)  # numeric, descending

switchableFormes = [
  "Deoxys"
  "Rotom"
  "Shaymin"
]

mustLearnMove =
  "Mamoswine"  : "AncientPower"
  "Yanmega"    : "AncientPower"
  "Tangrowth"  : "AncientPower"
  "Mr. Mime"   : "Mimic"
  "Sudowoodo"  : "Mimic"  # Note: Only 6 egg moves exist; 4 can be learned.
  "Ambipom"    : "Double Hit"
  "Lickilicky" : "Rollout"

getMinimumGeneration = (generation) ->
  for unportableGen in unportableGenerations
    if unportableGen <= generation
      return unportableGen
  minGeneration = Math.min(unportableGenerations...)
  throw new Error("Gen. '#{generation}' must be greater than #{minGeneration}.")

getGenerationFromInt = (generationInteger) ->
  INT_TO_GENERATION[generationInteger].toUpperCase()

# A helper method to loop through the learnsets for this pokemon and all
# prevolutions, and then runs an iterator function (that you give) on those
# learnsets. The iterator function takes one parameter, `learnset`, the learnset
# for a given generation for the Pokemon's current forme.
#
# All generations that can be used are taken into consideration.
loopLearnsets = (Generations, pokemon, forGeneration, iterator) ->
  minimumGeneration = getMinimumGeneration(forGeneration)
  {name, forme} = pokemon
  formeName = forme || "default"
  # Find pre-evolutions and formes
  thePokemon = []
  theFormes = [ formeName ]
  {SpeciesData, FormeData} = Generations[getGenerationFromInt(forGeneration)]
  while name
    thePokemon.push(name)
    if name in switchableFormes && name not in theFormes
      theFormes.push((forme  for forme of FormeData[name])...)
    if name not of SpeciesData
      console.log(SpeciesData)
    name = SpeciesData[name].evolvedFrom

  # Loop through pre-evolutions and formes
  for name in thePokemon
    for formeName in theFormes
      # Loop through all available generations
      for generation in [minimumGeneration..forGeneration]
        {FormeData} = Generations[getGenerationFromInt(generation)]
        # Skip if this pokemon has no data.
        continue  if !FormeData[name]?
        # Since we check pre-evos, the pre-evo may not have the forme that its
        # parent has. We check if no forme exists; if so, we revert to default.
        formeName = "default"  if formeName not of FormeData[name]
        learnset = FormeData[name][formeName].learnset
        # Skip if this Pokemon has no learnset for this generation.
        continue  if !learnset
        if iterator(learnset, name, formeName) == true then return true
  return false

# Returns an array of moves that this Pokemon can learn for a given generation.
self.learnableMoves = (Generations, pokemon, forGeneration) ->
  learnable = []
  loopLearnsets Generations, pokemon, forGeneration, (learnset, pokemonName, formeName) ->
    events = EventPokemon[pokemonName] || []
    events = events.filter((event) -> event.forme == formeName)
    for event in events
      learnable.push(event.moves)
    for method, moves of learnset
      learnable.push((moveName  for moveName of moves))
  _.chain(learnable).flatten().sort().unique().value()

# Checks the moveset of a given Pokemon for a given generation, with the given
# species and forme data for all Pokemon.
#
# Returns true if the moveset is valid, false otherwise.
self.checkMoveset = (Generations, pokemon, generation, moves) ->
  looper = loopLearnsets.bind(null, Generations, pokemon, generation)
  pokemonName = pokemon.name
  pokemonForme = pokemon.forme || "default"
  pokemonLevel = (pokemon.level || 100)
  {FormeData} = Generations[getGenerationFromInt(generation)]
  forme = FormeData[pokemonName][pokemonForme]

  # In gen 4, pokemon must know *all* moves inside the `form-change` learnset.
  if generation == 4
    rsForme = Generations.DP.FormeData[pokemonName]?[pokemonForme] || {}
    learnset = rsForme.learnset?['form-change'] || {}
    for move, level of learnset
      return false  if move not in moves || pokemonLevel < level

  # Get a list of all moves that the Pokemon can't learn
  # through level-up, tutoring, machines, or Sketch.
  leftoverMoves = (m  for m in moves when !checkMove(looper, pokemon, m))

  # Continuing the `forme-change` learnset group.
  # Get rid of leftover moves if this pokemon can learn it in this generation.
  learnset = forme.learnset?['form-change'] || {}
  lsetLeftovers = leftoverMoves.filter((move) -> pokemonLevel >= learnset[move])
  return true  if lsetLeftovers.length == leftoverMoves.length

  # Check against event Pokemon
  # TODO: Event Pokemon require more stringent checks, e.g. gender/ability etc.
  return true  if looper (learnset, pokemonName, formeName) ->
    events = EventPokemon[pokemonName] || []
    events = events.filter((event) -> event.forme == formeName)
    for event in events
      lsetLeftovers = leftoverMoves.filter (move) ->
        move in event.moves && pokemonLevel >= event.level
      return true  if lsetLeftovers.length == leftoverMoves.length

  # These learnset groups are non-standard but can be used. If a non-standard
  # group completely overlaps the leftover moves, the moveset is valid.
  nonstandardGroups = [ "light-ball-egg", "stadium-surfing-pikachu" ]
  return true  if looper (learnset) ->
    for group in nonstandardGroups
      continue  if !learnset[group]
      total = (m  for m in leftoverMoves when m of learnset[group]).length
      return true  if total == leftoverMoves.length

  # If the remaining moves are all dream world moves, it's a valid moveset.
  return true  if looper (learnset) ->
    return  if !learnset['dreamWorld']
    dreamWorldMoves = []
    for moveName of learnset['dreamWorld']
      continue  if moveName in dreamWorldMoves || moveName not in leftoverMoves
      dreamWorldMoves.push(moveName)
    return true  if leftoverMoves.length == dreamWorldMoves.length

  # This makes it so if the remaining moves are all egg moves, the moveset is
  # valid. That's false, but it's permissive. Later, factor in chain-breeding.
  # TODO: Check chain-breeding.
  eggMoves = []
  looper (learnset) ->
    return  if !learnset['egg']
    for moveName of learnset['egg']
      continue  if moveName in eggMoves || moveName not in leftoverMoves
      eggMoves.push(moveName)

  # If the Pokemon has to know a certain move to evolve, check the egg moves
  # since you cannot have a moveset made completely of pure egg moves.
  # A magic constant of 4 is used to imitate the game's maximum of 4 moves.
  return false  if eggMoves.length == 4 && mustLearnMove[pokemon.name]
  return true  if eggMoves.length == leftoverMoves.length

  return false

# Checks a single move to see if the Pokemon can learn it through level-up,
# tutors, machines, Sketch, or pre-evolutions.
checkMove = (looper, pokemon, move) ->
  {level} = pokemon
  level ||= 100

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
