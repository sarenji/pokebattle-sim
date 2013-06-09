{_} = require 'underscore'
{abilities, items, moves} = require '../data/bw'
{Status} = require './status'
{Attachments} = require './attachment'
util = require './util'
floor = Math.floor

class @Pokemon
  # TODO: Take the species obj, not attributes?
  constructor: (attributes = {}) ->
    @name = attributes.name || 'Missingno'
    @species = attributes.species
    @level = attributes.level || 100
    @baseStats = attributes.stats || {}
    @weight = attributes.weight  # in kg
    @gender = attributes.gender || "Genderless"
    @attachments = new Attachments()

    @nature = attributes.nature
    @evs = attributes.evs || {}
    @ivs = attributes.ivs || {}
    @currentHP = @stat('hp')

    @moves = attributes.moves?.map (move) ->
      moves[move.toLowerCase().replace(/\s+/g, '-')]
    @ppHash = {}
    if @moves?
      for move in @moves
        @ppHash[move.name] = @maxPP(move)
    @types = attributes.types || [] # TODO: Get from species.
    @item = items[attributes.item]
    @ability = abilities[attributes.ability]
    @status = null

    @stages =
      attack: 0
      defense: 0
      speed: 0
      specialDefense: 0
      specialAttack: 0
      evasion: 0
      accuracy: 0

    # What moves are blocked, and is switching blocked
    @blockedMoves = []
    @switchBlocked = false

    # a record of the last move used by this pokemon.
    @lastMove = null

  iv: (stat) => (if stat of @ivs then @ivs[stat] else 31)
  ev: (stat) => (if stat of @evs then @evs[stat] else 0)

  pp: (move) => @ppHash[move.name]
  maxPP: (move) => move.pp * 8/5

  reducePP: (move) =>
    @ppHash[move.name] -= 1  if @pp(move) > 0

  setPP: (move, pp) =>
    pp = Math.max(pp, 0)
    pp = Math.min(pp, @maxPP(move))
    @ppHash[move.name] = pp

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
    capitalized = key[0].toUpperCase() + key.substr(1)
    total = @item["modify#{capitalized}"](total, this)  if @item?
    total = @attachments.queryChain("modify#{capitalized}", total)
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
      if stat not of @stages
        throw new Error("Tried to boost non-existent stat #{stat} by #{amount}")
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
    else if arguments.length > 1
      @status in arguments
    else
      @status == status

  hasAttachment: (name) =>
    @attachments.contains(name)

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

  cureStatus: =>
    @status = null

  setItem: (battle, item) =>
    if @hasItem() then @removeItem()
    @item = item
    @item.initialize(battle, this)

  getItem: =>
    @item

  removeItem: =>
    @item.deactivate(this)
    @item = null

  isAlive: =>
    !@isFainted()

  isFainted: =>
    @currentHP <= 0

  faint: (battle) =>
    @currentHP = 0
    battle.message "#{@name} fainted!"

  damage: (amount) =>
    @setHP(@currentHP - amount)

  editDamage: (battle, move, damage) =>
    damage = @item.editDamage(battle, this, move, damage)  if @hasItem()
    damage

  editAccuracy: (accuracy) =>
    accuracy = @item.editAccuracy(accuracy)  if @hasItem()
    accuracy = @attachments.queryChain('editAccuracy', accuracy)
    accuracy

  editEvasion: (accuracy) =>
    accuracy = @attachments.queryChain('editEvasion', accuracy)
    accuracy

  setHP: (hp) =>
    @currentHP = Math.min(@stat('hp'), hp)

  recordHit: (pokemon, damage, move, turn) ->
    @lastHitBy = {pokemon, damage, move, turn}

  isImmune: (battle, type) =>
    b = @attachments.queryUntilNotNull('isImmune', battle, type)
    if b? then return b

    multiplier = util.typeEffectiveness(type, @types)
    return multiplier == 0

  calculateWeight: =>
    weight = @weight
    weight = @item.calculateWeight(weight)  if @item?
    weight = @attachments.queryChain('calculateWeight', weight)
    weight

  switchIn: (battle) =>
    @item?.initialize(battle, this)

  switchOut: (battle) =>
    @resetBoosts()
    @blockedMoves = []
    @switchBlocked = false
    delete @lastMove
    @attachments.query('switchOut', battle)

  beginTurn: (battle) =>
    @blockedMoves = []
    @switchBlocked = false
    @attachments.query('beginTurn', battle)

  afterTurnOrder: (battle) =>
    @item?.afterTurnOrder(battle, this)

  beforeMove: (battle, move, user, targets) =>
    @attachments.queryUntilFalse('beforeMove', battle, move, user, targets)

  update: (battle) =>
    @item?.update(battle, this)
    @attachments.query('update', battle, this)

  resetRecords: =>
    @lastHitBy = null

  # Hook for when the Pokemon gets hit by a move
  afterBeingHit: (battle, move, user, target, damage) =>
    @item?.afterBeingHit(battle, move, user, target, damage)
    @attachments.query('afterBeingHit', battle, move, user, target, damage)

  afterSuccessfulHit: (battle, move, user, target, damage) =>
    @item?.afterSuccessfulHit(battle, move, user, target, damage)
    @attachments.query('afterSuccessfulHit', battle, move, user, target, damage)

  endTurn: (battle) =>
    @item?.endTurn(battle, this)
    @attachments.query('endTurn', battle)

  # Adds an attachment to the list of attachments
  attach: (attachment, options={}) =>
    options = _.clone(options)
    options.pokemon = this
    @attachments.push(attachment, options)

  # Removes an attachment from the list of attachment
  unattach: (klass) =>
    attachment = @attachments.unattach(klass)
    delete attachment.pokemon

  # Blocks a move for a single turn
  blockMove: (move) =>
    @blockedMoves.push(move)

  isMoveBlocked: (move) =>
    return (move in @blockedMoves)

  isSwitchBlocked: =>
    @switchBlocked

  # Blocks a switch for a single turn
  blockSwitch: =>
    @switchBlocked = true

  # Locks the Pokemon into a single move. Does not limit switches.
  lockMove: (moveToLock) =>
    for move in @validMoves()
      @blockMove(move)  if move != moveToLock

  # A list of moves that this pokemon can use freely
  validMoves: =>
    _(@moves).difference(@blockedMoves)

  toString: =>
    "[Pokemon name:#{@name} hp:#{@currentHP}/#{@stat('hp')}]"


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

