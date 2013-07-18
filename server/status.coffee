{BaseAttachment} = require './attachment'
{Weather} = require './weather'
@Status = Status = {}

class @StatusAttachment extends BaseAttachment
  name: "StatusAttachment"

  @preattach: (options, attributes) ->
    {battle, pokemon} = attributes
    {source} = options
    return false  if pokemon.hasStatus()
    return false  if this == Status.Burn && pokemon.hasType("Fire")
    return false  if this == Status.Toxic && pokemon.hasType("Poison")
    return false  if this == Status.Poison && pokemon.hasType("Poison")
    return false  if this == Status.Freeze &&
      (pokemon.hasType("Ice") || battle?.hasWeather(Weather.SUN))
    if source && pokemon.hasAbility("Synchronize")
      return false  if source == pokemon
      source.attach(this)  # Do not attach source
      battle.message "#{pokemon.name} synchronized its status with #{source.name}!"
    pokemon.status = @name
    return true

  unattach: ->
    @pokemon.status = null

class @Status.Paralyze extends @StatusAttachment
  name: "Paralyze"

  beforeMove: (move, user, targets) ->
    if @battle.rng.next('paralyze chance') < .25
      @battle.message "#{@pokemon.name} is fully paralyzed!"
      return false

  editSpeed: (stat) ->
    if @pokemon.hasAbility("Quick Feet") then stat else stat >> 2

class @Status.Freeze extends @StatusAttachment
  name: "Freeze"

  beforeMove: (move, user, targets) ->
    if move.thawsUser || @battle.rng.next('unfreeze chance') < .2
      @battle.message "#{@pokemon.name} thawed out!"
      @pokemon.cureStatus()
    else
      @battle.message "#{@pokemon.name} is frozen solid!"
      return false

  afterBeingHit: (move, user, target, damage) ->
    if !move.isNonDamaging() && move.type == 'Fire'
      @battle.message "#{@pokemon.name} thawed out!"
      @pokemon.cureStatus()

class @Status.Poison extends @StatusAttachment
  name: "Poison"

  endTurn: ->
    return  if @pokemon.hasAbility("Poison Heal")
    @battle.message "#{@pokemon.name} was hurt by poison!"
    @pokemon.damage(@pokemon.stat('hp') >> 3)

class @Status.Toxic extends @StatusAttachment
  name: "Toxic"

  initialize: ->
    @counter = 0

  switchOut: ->
    @counter = 0

  endTurn: ->
    return  if @pokemon.hasAbility("Poison Heal")
    @battle.message "#{@pokemon.name} was hurt by poison!"
    @counter = Math.min(@counter + 1, 15)
    @pokemon.damage Math.floor(@pokemon.stat('hp') * @counter / 16)

class @Status.Sleep extends @StatusAttachment
  name: "Sleep"

  initialize: ->
    @counter = 0

  switchOut: ->
    @counter = 0

  beforeMove: (move, user, targets) ->
    if !@turns
      @turns = @battle.rng.randInt(1, 3, "sleep turns")
      @turns >>= 1  if @pokemon.hasAbility("Early Bird")
    if @counter == @turns
      @battle.message "#{@pokemon.name} woke up!"
      @pokemon.cureStatus()
    else
      @battle.message "#{@pokemon.name} is fast asleep."
      @counter += 1
      return false

class @Status.Burn extends @StatusAttachment
  name: "Burn"

  endTurn: ->
    @battle.message "#{@pokemon.name} was hurt by its burn!"
    @pokemon.damage(@pokemon.stat('hp') >> 3)
