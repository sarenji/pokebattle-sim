{_} = require 'underscore'
{abilities, items} = require '../data/bw'
floor = Math.floor

class @Pokemon
  constructor: (attributes = {}) ->
    @name = attributes.name || 'Missingno'
    @level = attributes.level || 100
    @baseStats = attributes.stats || {}

    @nature = attributes.nature
    @evs = attributes.evs || {}
    @ivs = attributes.ivs || {}
    @currentHP = @stat('hp')

    @moves = attributes.moves
    @types = attributes.types || [] # TODO: Get from species.
    @item = items[attributes.item]
    @ability = abilities[attributes.ability]
    @attachments = []

    @stages =
      attack: 0
      defense: 0
      speed: 0
      specialDefense: 0
      specialAttack: 0
      evasion: 0
      accuracy: 0

  iv: (stat) => @ivs[stat] || 31
  ev: (stat) => @evs[stat] || 0

  # Gets the stat indexed by key.
  # Ex: pokemon.stat('hp')
  # TODO: Precalculate the stats in the constructor
  stat: (key) =>
    base = @baseStats[key] || 100
    iv = @iv(key)
    ev = floor(@ev(key) / 4)
    total = if key == 'hp'
      floor((2 * base + iv + ev) * (@level / 100) + @level + 10)
    else
      floor(((2 * base + iv + ev) * (@level / 100) + 5) * @natureBoost(key))
    total = @statBoost(key, total)  if key != 'hp'
    total

  # Returns 1.1, 1.0, or 0.9 according to whether a Pokemon's nature corresponds
  # to that stat. The default return value is 1.0.
  natureBoost: (stat) =>
    nature = @nature?.toLowerCase()
    if nature of natures
      natures[nature][stat] || 1
    else
      1

  statBoost: (statName, total) =>
    boost = @stages[statName]
    if boost >= 0
      Math.floor((2 + boost) * total / 2)
    else
      Math.floor(2 * total / (2 - boost))

  # Returns a hashmap of the stats that were boosted. The keys are the stats.
  # If no stat was boosted, the value for that stat is false.
  boost: (boosts) =>
    boosted = {}
    for stat, amount of boosts
      previous = @stages[stat]
      @stages[stat] += amount
      @stages[stat] = Math.max(-6, @stages[stat])
      @stages[stat] = Math.min(6, @stages[stat])
      boosted[stat] = (@stages[stat] != previous)
    boosted

  hasType: (type) =>
    type in @types

  hasAbility: (abilityName) =>
    @ability?.name == abilityName

  hasItem: (itemName) =>
    if itemName?
      @item?.name == itemName
    else
      @item?

  hasStatus: (status) =>
    status in @attachments.map((s) -> s.name)

  hasAttachment: (name) =>
    name in @attachments.map((a) -> a.name)

  isFainted: =>
    @currentHP <= 0

  damage: (amount) =>
    @currentHP -= amount
    @currentHP = Math.min(@stat('hp'), @currentHP)

  attach: (attachment) =>
    @attachments.push(attachment)

# A hash that keys a nature with the stats that it boosts.
# Neutral natures are ignored.
# TODO: .yml-ify these.
PLUS  = 1.1
MINUS = 0.9
natures =
  lonely:  {attack: PLUS, defense: MINUS}
  brave:   {attack: PLUS, speed: MINUS}
  adamant: {attack: PLUS, specialAttack: MINUS}
  naughty: {attack: PLUS, specialDefense: MINUS}
  bold:    {defense: PLUS, attack: MINUS}
  relaxed: {defense: PLUS, speed: MINUS}
  impish:  {defense: PLUS, specialAttack: MINUS}
  lax:     {defense: PLUS, specialDefense: MINUS}
  timid:   {speed: PLUS, attack: MINUS}
  hasty:   {speed: PLUS, defense: MINUS}
  jolly:   {speed: PLUS, specialAttack: MINUS}
  naive:   {speed: PLUS, specialDefense: MINUS}
  modest:  {specialAttack: PLUS, attack: MINUS}
  mild:    {specialAttack: PLUS, defense: MINUS}
  quiet:   {specialAttack: PLUS, speed: MINUS}
  rash:    {specialAttack: PLUS, specialDefense: MINUS}
  calm:    {specialDefense: PLUS, attack: MINUS}
  gentle:  {specialDefense: PLUS, defense: MINUS}
  sassy:   {specialDefense: PLUS, speed: MINUS}
  careful: {specialDefense: PLUS, specialAttack: MINUS}

