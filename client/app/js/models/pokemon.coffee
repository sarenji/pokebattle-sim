class @Pokemon extends Backbone.Model
  defaults: =>
    moves: []
    pixels: 48
    ivs:
      hp: 31
      attack: 31
      defense: 31
      specialAttack: 31
      specialDefense: 31
      speed: 31
    evs:
      hp: 0
      attack: 0
      defense: 0
      specialAttack: 0
      specialDefense: 0
      speed: 0

  initialize: (attributes={}) ->
    # History lesson: We stored species under `name`. Now that we support
    # nicknames, we need the `name` freed up. However, teams are saved to the
    # server using the old scheme. Therefore we need to do a simple check for
    # the existence of `species`; if it exists, do nothing. If not, use `name`.
    @set('species', @get('name'))  if !@has('species') && @has('name')
    @set('forme', 'default')  unless @has('forme')
    @normalizeStats(@get('ivs'), 31)
    @normalizeStats(@get('evs'), 0)
    @resetBoosts()
    @isNull = false

    # Skip teambuilder-specific properties.
    return  if @get('teambuilder') != true

    @on 'change:ivs', (model, ivs)=>
      type = HiddenPower.BW.type(ivs).toLowerCase()
      @set("hiddenPowerType", type, silent: true)

    @on 'change:hiddenPowerType', (model, type) =>
      hpIVs = HiddenPower.BW.ivs[type.toLowerCase()]
      ivs = @get('ivs')
      for stat, iv of ivs
        ivs[stat] = hpIVs[stat] || 31
      @set('ivs', ivs, silent: true)

    @set('ability', @getAbilities()[0])  unless attributes.ability
    @set('level', 100)  unless attributes.level
    @set('happiness', 100)  if isNaN(attributes.happiness)
    @set('nature', 'Hardy')  unless attributes.nature
    hiddenPowerType = HiddenPower.BW.type(@get('ivs')).toLowerCase()
    @set('hiddenPowerType', hiddenPowerType, silent: true)

    # If there is no gender set and only one possiblity, set the gender
    unless @has('gender')
      genders = @getGenders()
      @set('gender', genders[0], silent: true) if genders.length == 1

  resetBoosts: ->
    @set 'stages',
      hp: 0
      attack: 0
      defense: 0
      specialAttack: 0
      specialDefense: 0
      speed: 0
      accuracy: 0
      evasion: 0

  normalizeStats: (hash, defaultValue) ->
    stats = [ "hp", "attack", "defense", "specialAttack",
              "specialDefense", "speed"]
    for stat in stats
      hash[stat] ?= defaultValue

  getGeneration: (generation) ->
    gen = generation || @collection?.generation || DEFAULT_GENERATION
    gen = gen.toUpperCase()
    window.Generations[gen]

  getSpecies: ->
    @getGeneration().SpeciesData[@get('species')]

  getItem: ->
    @getGeneration().ItemData[@get('item')]

  getForme: (forme, generation) ->
    forme ||= @get('forme')
    @getGeneration(generation).FormeData[@get('species')]?[forme]

  getFormes: ->
    (forme  for forme of @getGeneration().FormeData[@get('species')])

  # Returns all non-battle only formes
  getSelectableFormes: ->
    _(@getFormes()).reject((forme) => @getForme(forme).isBattleOnly)

  getAbilities: ->
    forme = @getForme()
    abilities = _.clone(forme.abilities)
    abilities.push(forme.hiddenAbility)  if forme.hiddenAbility
    _.unique(abilities)

  getGenders: ->
    species = @getSpecies()
    genders = []
    switch species.genderRatio
      when -1
        genders.push("Genderless")
      when 0
        genders.push("M")
      when 8
        genders.push("F")
      else
        genders.push("M", "F")
    genders

  getMovepool: ->
    {SpeciesData, MoveData} = @getGeneration()
    generation = GENERATION_TO_INT[@collection?.generation || DEFAULT_GENERATION]
    learnset = learnableMoves(window.Generations, @attributes, generation)

    # Map each move name to a move object
    return _(learnset).map (moveName) ->
      move = _(MoveData[moveName]).clone()
      move['name'] = moveName
      move

  getTotalEVs: (options = {}) ->
    total = 0
    for stat, value of @get("evs")
      total += value  if stat != options.exclude
    total

  getTeam: =>
    @collection?.parents[0]

  setIv: (stat, value) ->
    ivs = _.clone(@get("ivs"))
    ivs[stat] = value
    @set("ivs", ivs)  # trigger change event

  setEv: (stat, value) ->
    evs = _.clone(@get("evs"))
    value = value - (value % 4)
    evs[stat] = value
    @set("evs", evs)  # trigger change event
    value

  iv: (stat) ->
    @get("ivs")[stat] ? 31

  ev: (stat) ->
    @get("evs")[stat] ? 0

  natureBoost: (stat) ->
    nature = @get('nature')?.toLowerCase()
    if nature of natures
      natures[nature][stat] || 1
    else
      1

  base: (key) ->
    forme = @getForme()
    base = forme["stats"][key]

  stat: (key) ->
    base = @base(key)
    return 1  if base == 1  # For Shedinja. key doesn't have to be hp.
    level = @get('level') || 100
    iv = @iv(key)
    ev = Math.floor(@ev(key) / 4)
    total = if key == 'hp'
      Math.floor((2 * base + iv + ev) * (level / 100) + level + 10)
    else
      Math.floor(((2 * base + iv + ev) * (level / 100) + 5) * @natureBoost(key))

  # Returns the natures that this pokemon can use
  # The natures are returned as a list of [id, value] values
  # to populate a dropdown field.
  # TODO: Should this be needed in more places, return Nature objects instead
  getNatures: ->
    natureResults = []
    for nature, stats of natures
      name = nature[0].toUpperCase() + nature.substr(1)
      invertedStats = _(stats).invert()
      
      label = name
      if invertedStats[PLUS]
        # This nature has an effect, so update the label
        plusStat = statAbbreviations[invertedStats[PLUS]]
        minusStat = statAbbreviations[invertedStats[MINUS]]
        label = "#{name} (+#{plusStat}, -#{minusStat})"

      natureResults.push [name, label]
    return natureResults

  getPBV: ->
    gen = @getGeneration()
    PokeBattle.PBV.determinePBV(gen, @attributes)

  setPP: (moveIndex, newPP) ->
    array = _.clone(@get('pp'))
    array[moveIndex] = newPP
    @set('pp', array)

  getPercentHP: ->
    Math.floor(100 * @get('pixels') / 48)

  getHPColor: ->
    percent = @getPercentHP()
    switch
      when percent < 20 then 'red'
      when percent < 50 then 'yellow'
      else                   'green'

  isFainted: ->
    @get('pixels') <= 0

  getStatus: ->
    status = @get('status')
    if status
      "#{status[0].toUpperCase()}#{status.substr(1)}"
    else
      "Healthy"

  canMegaEvolve: ->
    item = @getItem()
    return false  if item.type != 'megastone'
    [ species, forme ] = item.mega
    return false  if @get('species') != species || @get('forme') != 'default'
    return true

  # Returns the complete web address to the pokedex link for this pokemon.
  # For this project, this leads to our website at http://www.pokebattle.com,
  # but if you want it to lead somewhere else, edit this function.
  getPokedexUrl: ->
    # todo: move this function to /shared, or use an actual slugify library
    slugify = (str) ->
      str.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/\-{2,}/g, '-')

    slugSpecies = slugify(@get('species'))
    slugForme = slugify(@get('forme'))
    "//pokebattle.com/dex/pokemon/#{slugSpecies}/#{slugForme}"

  toJSON: ->
    attributes = _.clone(@attributes)
    delete attributes.gender  if attributes.gender == 'Genderless'
    delete attributes.hiddenPowerType
    delete attributes.teambuilder
    attributes

# TODO: These shortenings really should be stored somewhere else.
statAbbreviations =
  'hp'             : 'HP'
  'attack'         : 'Atk'
  'defense'        : 'Def'
  'specialAttack'  : 'SAtk'
  'specialDefense' : 'SDef'
  'speed'          : 'Spe'

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
  hardy:   {}
  docile:  {}
  serious: {}
  bashful: {}
  quirky:  {}

class @NullPokemon extends Pokemon
  initialize: ->
    @set('species', null)
    @set('forme', 'default')
    @isNull = true

  getNatures: -> []
  getPBV: -> 0
  base: -> 0
  stat: -> null
  iv: -> null
  ev: -> null

  getSpecies: ->
    id: 0
    genderRatio: -1
    generation: 1

  getForme: ->
    @getFormes()['default']

  getFormes: ->
    default:
      abilities: []
      hiddenAbility: null
      isBattleOnly: false
      learnset: {}
      types: []
