HiddenPower = (if module? then require('../../../../shared/hidden_power') else window.HiddenPower ?= {})

@PokeBattle ?= {}
@PokeBattle.parseTeam = (teamString) ->
  text = teamString.split('\n')
  team = []
  pokemonRegex = /^(.*?)\s*(\(M\)|\(F\)|)?(?:\s*@\s*(.*))?$/
  pokemon = null
  for line in text
    line = line.trim()
    if line.length == 0
      pokemon = null
    else if !pokemon
      [ all, pokemonLine, gender, item ] = line.match(pokemonRegex)
      pokemon = {}
      team.push(pokemon)

      # Ignore nicknames for now
      pokemonLine    = RegExp.$1  if pokemonLine.match(/.*?\s*\((.*)\)/)
      convertNameToSpeciesAndForme(pokemon, pokemonLine.trim())
      pokemon.gender = gender[1]  if gender  # (M) and (F)
      pokemon.item   = item    if item
      for olditem, newitem of Aliases.items
        if olditem is pokemon.item
          pokemon.item = newitem
    else if line.match(/^(?:Trait|Ability):\s+(.*)$/i)
      pokemon.ability = RegExp.$1
      for oldability, newability of Aliases.abilities
        if pokemon.ability is oldability
          pokemon.ability = newability
    else if line.match(/^Level:\s+(.*)$/i)
      pokemon.level = Number(RegExp.$1) || 100
    else if line.match(/^Happiness:\s+(.*)$/i)
      pokemon.happiness = Number(RegExp.$1) || 0
    else if line.match(/^Shiny: Yes$/i)
      pokemon.shiny = true
    else if line.match(/^EVs: (.*)$/i)
      evs = RegExp.$1.split(/\//g)
      pokemon.evs = {}
      for ev in evs
        ev = ev.trim()
        [ numberString, rawStat ] = ev.split(/\s+/)
        pokemon.evs[statsHash[rawStat]] = Number(numberString) || 0
    else if line.match(/^IVs: (.*)$/i)
      ivs = RegExp.$1.split(/\//g)
      pokemon.ivs = {}
      for iv in ivs
        iv = iv.trim()
        [ numberString, rawStat ] = iv.split(/\s+/)
        pokemon.ivs[statsHash[rawStat]] = Number(numberString) || 0
    else if line.match(/^([A-Za-z]+) nature/i)
      pokemon.nature = RegExp.$1
    else if line.match(/^[\-\~]\s*(.*)/)
      moveName = RegExp.$1
      for oldmove, newmove of Aliases.moves
        if moveName is oldmove
          moveName = newmove
      if /Hidden Power /.test(moveName)
        if !pokemon.ivs
          moveName.match(/Hidden Power (.*)/i)
          hiddenPowerType = RegExp.$1.trim().toLowerCase().replace(/\W+/g, '')
          pokemon.ivs = HiddenPower.BW.ivs[hiddenPowerType] || {}
        moveName = 'Hidden Power'
      pokemon.moves ?= []
      pokemon.moves.push(moveName)
  return team

@PokeBattle.exportTeam = (json) ->
  s = []
  for pokemon in json
    s.push("")

    # Pokemon name
    name = pokemon.name
    if pokemon.forme && pokemon.forme != "default"
      name += "-#{pokemon.forme[0].toUpperCase()}"
    name += " (#{pokemon.gender})"  if pokemon.gender
    name += " @ #{pokemon.item}"  if pokemon.item
    s.push(name)

    # Ability
    s.push("Ability: #{pokemon.ability}")  if pokemon.ability

    # EVs
    if pokemon.evs
      evArray = for stat, amount of pokemon.evs when amount > 0
        "#{amount} #{reverseStatsHash[stat]}"
      s.push("EVs: #{evArray.join(" / ")}")  if evArray.length > 0

    # IVs
    if pokemon.ivs
      ivArray = for stat, amount of pokemon.ivs when amount < 31
        "#{amount} #{reverseStatsHash[stat]}"
      s.push("IVs: #{ivArray.join(" / ")}")  if ivArray.length > 0

    # Nature
    s.push("#{pokemon.nature} nature")  if pokemon.nature

    # Level
    s.push("Level: #{pokemon.level}")  if pokemon.level && pokemon.level != 100

    # Shiny
    s.push("Shiny: Yes")  if pokemon.shiny

    # Happiness
    if pokemon.happiness && pokemon.happiness != 100
      s.push("Happiness: #{pokemon.happiness}")

    # Moves
    if pokemon.moves
      s.push("- #{moveName}")  for moveName in pokemon.moves
  s.push("\n")  # Trailing newlines, just in case.
  s.join("\n")

Aliases =
  moves:
    "Ancient Power"   :  "AncientPower"
    "Bubble Beam"     :  "BubbleBeam"
    "Double Slap"     :  "DoubleSlap"
    "Dragon Breath"   :  "DragonBreath"
    "Dynamic Punch"   :  "DynamicPunch"
    "Extreme Speed"   :  "ExtremeSpeed"
    "Feint Attack"    :  "Faint Attack"
    "Feather Dance"   :  "FeatherDance"
    "Grass Whistle"   :  "GrassWhistle"
    "High Jump Kick"  :  "Hi Jump Kick"
    "Poison Powder"   :  "PoisonPowder"
    "Sand Attack"     :  "Sand-Attack"
    "Self-Destruct"   :  "Selfdestruct"
    "Smelling Salts"  :  "SmellingSalt"
    "Smokescreen"     :  "SmokeScreen"
    "Soft-Boiled"     :  "Softboiled"
    "Solar Beam"      :  "SolarBeam"
    "Sonic Boom"      :  "SonicBoom"
    "Thunder Punch"   :  "ThunderPunch"
    "Thunder Shock"   :  "ThunderShock"
    "Vice Grip"       :  "ViceGrip"
  abilities:
    "Compound Eyes"   :  "Compoundeyes"
    "Lightning Rod"   :  "Lightningrod"
  items:
    "Balm Mushroom"   :  "BalmMushroom"
    "Black Glasses"   :  "BlackGlasses"
    "Bright Powder"   :  "BrightPowder"
    "Deep Sea Scale"  :  "DeepSeaScale"
    "Deep Sea Tooth"  :  "DeepSeaTooth"
    "Energy Powder"   :  "EnergyPowder"
    "Never-MeltIce"   :  "NeverMeltIce"
    "Parlyze Heal"    :  "Paralyz Heal"
    "Rage Candy Bar"  :  "RageCandyBar"
    "Silver Powder"   :  "SilverPowder"
    "Thunder Stone"   :  "Thunderstone"
    "Tiny Mushroom"   :  "TinyMushroom"
    "Twisted Spoon"   :  "TwistedSpoon"

statsHash =
  'hp'   : 'hp'
  'Hp'   : 'hp'
  'HP'   : 'hp'
  'Atk'  : 'attack'
  'Def'  : 'defense'
  'SAtk' : 'specialAttack'
  'SpA'  : 'specialAttack'
  'SDef' : 'specialDefense'
  'SpD'  : 'specialDefense'
  'Spe'  : 'speed'
  'Spd'  : 'speed'

reverseStatsHash =
  'hp'             : 'HP'
  'attack'         : 'Atk'
  'defense'        : 'Def'
  'specialAttack'  : 'SAtk'
  'specialDefense' : 'SDef'
  'speed'          : 'Spe'

convertNameToSpeciesAndForme = (pokemon, name) ->
  if name.match(/(Thundurus|Landorus|Tornadus)\-T(herian)?/i)
    pokemon.name = RegExp.$1
    pokemon.forme = 'therian'
  else if name.match(/Shaymin-S(ky)?/i)
    pokemon.name = "Shaymin"
    pokemon.forme = 'sky'
  else if name.match(/Giratina-O(rigin)?/i)
    pokemon.name = "Giratina"
    pokemon.forme = 'origin'
  else if name.match(/Arceus(\-.*)?/)
    pokemon.name = "Arceus"
  else if name.match(/Kyurem-B(lack)?/)
    pokemon.name = "Kyurem"
    pokemon.forme = "black"
  else if name.match(/Kyurem-W(hite)?/)
    pokemon.name = "Kyurem"
    pokemon.forme = "white"
  else if name.match(/Rotom-W|Rotom-Wash/)
    pokemon.name = "Rotom"
    pokemon.forme = "wash"
  else if name.match(/Rotom-S|Rotom-Fan/)
    pokemon.name = "Rotom"
    pokemon.forme = "fan"
  else if name.match(/Rotom-H|Rotom-Heat/)
    pokemon.name = "Rotom"
    pokemon.forme = "heat"
  else if name.match(/Rotom-F|Rotom-Frost/)
    pokemon.name = "Rotom"
    pokemon.forme = "frost"
  else if name.match(/Rotom-C|Rotom-Mow/)
    pokemon.name = "Rotom"
    pokemon.forme = "mow"
  else if name.match(/Deoxys-A|Deoxys-Attack/)
    pokemon.name = "Deoxys"
    pokemon.forme = "attack"
  else if name.match(/Deoxys-D|Deoxys-Defense/)
    pokemon.name = "Deoxys"
    pokemon.forme = "defense"
  else if name.match(/Deoxys-S|Deoxys-Speed/)
    pokemon.name = "Deoxys"
    pokemon.forme = "speed"
  else if name.match(/Basculin-Blue-Striped|Basculin-A/)
    pokemon.name = "Basculin"
    pokemon.forme = "blue-striped"
  else if name.match(/Keldeo-Resolute|Keldeo-R/)
    pokemon.name = "Keldeo"
    pokemon.forme = "resolute"
  else if name.match(/Shellos-East/)
    pokemon.name = "Shellos"
    # TODO: Read east forme
    pokemon.forme = "default"
  else if name.match(/Gastrodon-East/)
    pokemon.name = "Gastrodon"
    # TODO: Read east forme
    pokemon.forme = "default"
  else if name.match(/Wormadam-Sandy|Wormadam-G/)
    pokemon.name = "Wormadam"
    pokemon.forme = "sandy"
  else if name.match(/Wormadam-Trash|Wormadam-S/)
    pokemon.name = "Wormadam"
    pokemon.forme = "trash"
  else if name.match(/Deerling-.*/)
    pokemon.name = "Deerling"
    # TODO: Read other formes
    pokemon.forme = null
  else if name.match(/Sawsbuck-.*/)
    pokemon.name = "Sawsbuck"
    # TODO: Read other formes
    pokemon.forme = null
  else if name.match(/Unown-.*/)
    pokemon.name = "Unown"
    # TODO: Read other formes
    pokemon.forme = null
  else
    pokemon.name = name
