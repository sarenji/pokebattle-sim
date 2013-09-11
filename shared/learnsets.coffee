self = (module?.exports || window)

if module?.exports
  EventPokemon = require('./event_pokemon')
else
  window.EventPokemon ?= {}

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

# A helper method to loop through the learnsets for this pokemon and all
# prevolutions, and then runs an iterator function (that you give) on those
# learnsets. The iterator function takes one parameter, `learnset`, the learnset
# for a given generation for the Pokemon's current forme.
#
# All generations that can be used are taken into consideration.
loopLearnsets = (SpeciesData, FormeData, pokemon, forGeneration, iterator) ->
  minimumGeneration = getMinimumGeneration(forGeneration)
  {name, forme} = pokemon
  formeName = forme || "default"
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
  forme = FormeData[pokemon.name][pokemon.forme || "default"]
  pokemonLevel = (pokemon.level || 100)

  # In gen 4, pokemon must know *all* moves inside the `form-change` learnset.
  if generation == 4
    learnset = forme.learnset["generation-4"]?['form-change'] || {}
    for move, level of learnset
      return false  if move not in moves || pokemonLevel < level

  # Get a list of all moves that the Pokemon can't learn
  # through level-up, tutoring, machines, or Sketch.
  leftoverMoves = (m  for m in moves when !checkMove(looper, pokemon, m))

  # Continuing the `forme-change` learnset group.
  # Get rid of leftover moves if this pokemon can learn it in this generation.
  learnset = forme.learnset["generation-#{generation}"]?['form-change'] || {}
  lsetLeftovers = leftoverMoves.filter((move) -> pokemonLevel >= learnset[move])
  return true  if lsetLeftovers.length == leftoverMoves.length

  # Check against event Pokemon
  # TODO: Event Pokemon require more stringent checks, e.g. gender/ability etc.
  events = EventPokemon[pokemon.name] || []
  events = events.filter((event) -> event.forme == pokemon.forme || "default")
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
