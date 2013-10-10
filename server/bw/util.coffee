@roundHalfDown = (number) ->
  Math.ceil(number - .5)

cleanStats =
  attack: "Attack"
  defense: "Defense"
  speed: "Speed"
  specialAttack: "Special Attack"
  specialDefense: "Special Defense"
  accuracy: "Accuracy"
  evasion: "Evasion"

makeBoostMessage = (pokemon, stat, amount, wasBoosted) ->
  stat = cleanStats[stat]
  if wasBoosted && amount > 0
    adverb = ""              if amount == 1
    adverb = " sharply"      if amount == 2
    adverb = " drastically"  if amount >= 3
    "#{pokemon.name}'s #{stat} rose#{adverb}!"
  else if wasBoosted && amount < 0
    adverb = ""           if amount == -1
    adverb = " harshly"   if amount == -2
    adverb = " severely"  if amount <= -3
    "#{pokemon.name}'s #{stat}#{adverb} fell!"
  else if !wasBoosted && amount > 0
    "#{pokemon.name}'s #{stat} won't go any higher!"
  else if !wasBoosted && amount < 0
    "#{pokemon.name}'s #{stat} won't go any lower!"

@printBoostMessage = (battle, pokemon, boostedStats, amountHash) ->
  for stat, wasBoosted of boostedStats
    message = makeBoostMessage(pokemon, stat, amountHash[stat], wasBoosted)
    battle.message(message)  if message?
  true

@typeEffectiveness = (userType, againstTypes, options = {}) ->
  userType = Type[userType.toUpperCase()]
  effectiveness = 1
  for subtype in againstTypes
    targetType = Type[subtype.toUpperCase()]
    multiplier = typeChart[userType][targetType]
    multiplier = 1  if multiplier == 0 && options.ignoreImmunities
    effectiveness *= multiplier
  effectiveness

@Type = Type =
  NORMAL   : 0
  FIRE     : 1
  WATER    : 2
  ELECTRIC : 3
  GRASS    : 4
  ICE      : 5
  FIGHTING : 6
  POISON   : 7
  GROUND   : 8
  FLYING   : 9
  PSYCHIC  : 10
  BUG      : 11
  ROCK     : 12
  GHOST    : 13
  DRAGON   : 14
  DARK     : 15
  STEEL    : 16
  "???"    : 17

typeChart = [
  # Nor Fir Wat Ele Gra Ice Fig Poi Gro Fly Psy Bug Roc Gho Dra Dar Ste ???
  [  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1, .5,  0,  1,  1, .5,  1 ], # Nor
  [  1, .5, .5,  1,  2,  2,  1,  1,  1,  1,  1,  2, .5,  1, .5,  1,  2,  1 ], # Fir
  [  1,  2, .5,  1, .5,  1,  1,  1,  2,  1,  1,  1,  2,  1, .5,  1,  1,  1 ], # Wat
  [  1,  1,  2, .5, .5,  1,  1,  1,  0,  2,  1,  1,  1,  1, .5,  1,  1,  1 ], # Ele
  [  1, .5,  2,  1, .5,  1,  1, .5,  2, .5,  1, .5,  2,  1, .5,  1, .5,  1 ], # Gra
  [  1, .5, .5,  1,  2, .5,  1,  1,  2,  2,  1,  1,  1,  1,  2,  1, .5,  1 ], # Ice
  [  2,  1,  1,  1,  1,  2,  1, .5,  1, .5, .5, .5,  2,  0,  1,  2,  2,  1 ], # Fig
  [  1,  1,  1,  1,  2,  1,  1, .5, .5,  1,  1,  1, .5, .5,  1,  1,  0,  1 ], # Poi
  [  1,  2,  1,  2, .5,  1,  1,  2,  1,  0,  1, .5,  2,  1,  1,  1,  2,  1 ], # Gro
  [  1,  1,  1, .5,  2,  1,  2,  1,  1,  1,  1,  2, .5,  1,  1,  1, .5,  1 ], # Fly
  [  1,  1,  1,  1,  1,  1,  2,  2,  1,  1, .5,  1,  1,  1,  1,  0, .5,  1 ], # Psy
  [  1, .5,  1,  1,  2,  1, .5, .5,  1, .5,  2,  1,  1, .5,  1,  2, .5,  1 ], # Bug
  [  1,  2,  1,  1,  1,  2, .5,  1, .5,  2,  1,  2,  1,  1,  1,  1, .5,  1 ], # Roc
  [  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2,  1,  1,  2,  1, .5, .5,  1 ], # Gho
  [  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2,  1, .5,  1 ], # Dra
  [  1,  1,  1,  1,  1,  1, .5,  1,  1,  1,  2,  1,  1,  2,  1,  1, .5,  1 ], # Dar
  [  1, .5, .5, .5,  1,  2,  1,  1,  1,  1,  1,  1,  2,  1,  1,  1, .5,  1 ], # Ste
  [  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1 ]  # ???
]
