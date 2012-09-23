{_} = require 'underscore'
{abilities, items} = require '../data/bw'
{Status} = require './status'
{BurnAttachment, ParalyzeAttachment, FreezeAttachment, SleepAttachment,
PoisonAttachment, ToxicAttachment} = require './attachment'
floor = Math.floor

class @Pokemon
  # TODO: Take the species obj, not attributes?
  constructor: (attributes = {}) ->
    @name = attributes.name || 'Missingno'
    @species = attributes.species
    @level = attributes.level || 100
    @baseStats = attributes.stats || {}
    @weight = attributes.weight

    @nature = attributes.nature
    @evs = attributes.evs || {}
    @ivs = attributes.ivs || {}
    @currentHP = @stat('hp')

    @moves = attributes.moves
    @types = attributes.types || [] # TODO: Get from species.
    @item = items[attributes.item]
    @ability = abilities[attributes.ability]
    @status = null
    @attachments = []

    @stages =
      attack: 0
      defense: 0
      speed: 0
      specialDefense: 0
      specialAttack: 0
      evasion: 0
      accuracy: 0

    # a list of moves blocked for this turn
    @blockedMoves = []

  iv: (stat) => (if stat of @ivs then @ivs[stat] else 31)
  ev: (stat) => (if stat of @evs then @evs[stat] else 0)

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

  # Boosts this pokemon's stats by the given number of stages.
  # Returns a hashmap of the stats that were boosted. The keys are the stats.
  # If no stat was boosted, the value for that stat is false.
  #
  # Example: pokemon.boost(specialAttack: 1, evasion: 2)
  #
  boost: (boosts) =>
    boosted = {}
    for stat, amount of boosts
      previous = @stages[stat]
      @stages[stat] += amount
      @stages[stat] = Math.max(-6, @stages[stat])
      @stages[stat] = Math.min(6, @stages[stat])
      boosted[stat] = (@stages[stat] != previous)
    boosted

  resetBoosts: =>
    @stages.attack = 0
    @stages.defense = 0
    @stages.speed = 0
    @stages.specialAttack = 0
    @stages.specialDefense = 0
    @stages.accuracy = 0
    @stages.evasion = 0

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
    if !status?
      statusArray = (value  for key, value of Status)
      @status in statusArray
    else
      @status == status

  hasAttachment: (name) =>
    name in @attachments.map((a) -> a.name)

  # Sets the Pokemon's status. If it succeeds, returns true, otherwise false.
  setStatus: (newStatus) =>
    if !@status? && !@hasStatus()
      @status = newStatus
      true
    else
      false

  removeStatus: (status) =>
    if !status? || @status == status
      @status = null

  isFainted: =>
    @currentHP <= 0

  damage: (amount) =>
    @setHP(@currentHP - amount)

  setHP: (hp) =>
    @currentHP = Math.min(@stat('hp'), hp)

  isImmune: (move, battle, user) =>
    multiplier = move.typeEffectiveness(battle, user, this)
    multiplier == 0

  switchOut: (battle) =>
    @resetBoosts()
    @blockedMoves = []
    attachment.switchOut(battle)  for attachment in _.clone(@attachments)

  beginTurn: (battle) =>
    @blockedMoves = []
    attachment.beginTurn(battle)  for attachment in _.clone(@attachments)

  endTurn: (battle) =>
    @item?.endTurn(battle, this)
    attachment.endTurn(battle)  for attachment in _.clone(@attachments)

  # Adds an attachment to the list of attachments
  attach: (attachment) =>
    # TODO: Error if the attachment already has a pokemon
    @attachments.push(attachment)
    attachment.pokemon = this

  # Removes an attachment from the list of attachment
  # TODO: Also accept a string?
  unattach: (attachment) =>
    # TODO: Error if the attachment is not in the list
    index = @attachments.indexOf(attachment)
    @attachments.splice(index, 1)
    attachment.pokemon = undefined

  # Blocks a move for a single turn
  blockMove: (moveName) =>
    @blockedMoves.push(moveName)

  isMoveBlocked: (moveName) =>
    return (moveName in @blockedMoves)

  # A list of moves that this pokemon can use freely
  validMoves: =>
    _(@moves).difference(@blockedMoves)


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

