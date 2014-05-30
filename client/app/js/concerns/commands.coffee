PokeBattle.commands ?= {}

Commands = {}

desc = (description) ->
  desc.lastDescription = description

makeCommand = (commandNames..., func) ->
  for commandName in commandNames
    Commands[commandName] = func

  # Generate description
  description = ""
  if commandNames.length > 1
    aliases = commandNames[1...].map((n) -> "/#{n}").join(', ')
    description += " <i>Also #{aliases}. </i>"
  description += desc.lastDescription
  # TODO: Hardcoded user level
  HelpDescriptions['1'][commandNames[0]] = description
  delete desc.lastDescription

parseCommand = (line) ->
  [ commandName, args... ] = line.split(/\s+/)
  if commandName[0] == '/'
    # It's a command. Remove leading slash
    commandName = commandName[1...]
    args = args.join(' ').split(/,/g)
    return [commandName, args]
  return null

PokeBattle.commands.execute = (line) ->
  result = parseCommand(line)
  return false  if !result
  [commandName, args] = result
  command = Commands[commandName]
  if !command
    # Fall-through to server.
    return false
  command(args...)
  return true

desc 'Displays a list of all commands.'
makeCommand "help", "h", ->
  user = PokeBattle.userList.get(PokeBattle.username)
  return  unless user

  for level, descriptions of HelpDescriptions
    level = Number(level)
    continue  if user.get('authority') < level

    message = []
    # TODO: Hardcoded levels
    authLevels = {1: "USER", 2: "DRIVER", 3: "MOD", 4: "ADMIN", 5: "OWNER"}
    humanLevel = authLevels[level]
    message.push("<b>#{humanLevel} COMMANDS:</b>")
    for name, description of descriptions
      message.push("<b>/#{name}:</b> #{description}")
    message = message.join("<br>")
    PokeBattle.chatView.announce('success', message)

desc 'Opens the challenge for a specific user. Usage: /challenge username'
makeCommand "challenge", "chall", "c", (username) ->
  if !username
    PokeBattle.events.trigger("error", "Usage: /challenge username")
    return
  message = PokeBattle.messages.add(id: username)
  message.openChallenge(username)

desc 'Private messages a certain user. Usage: /message username, message'
makeCommand "message", "msg", "pm", "whisper", "w", (username, messages...) ->
  username = username?.trim()
  if !username
    PokeBattle.events.trigger("error", "Usage: /message username, message")
    return
  message = PokeBattle.messages.add(id: username)

  if messages.length > 0
    text = messages.join(',')
    PokeBattle.socket.send('privateMessage', message.id, text)
  else
    # The PM is opened without a message.
    message.trigger('open', message)

desc 'Clears the chat.'
makeCommand "clear", ->
  PokeBattle.chatView.clear()

desc 'Displays how much PBV a Pokemon is worth, or displays all Pokemon at or under a particular PBV. Usage: /pbv pkmn1, pkmn2, OR /pbv number'
makeCommand "pbv", (pokemon...) ->
  pbv = Number(pokemon[0])
  if !isNaN(pbv)
    messages = findPokemonAtPBV(pbv)
  else
    messages = findTotalPBV(pokemon)

  if messages.length == 0
    PokeBattle.chatView.announce('error',
      "<b>PBV error:</b> Enter valid Pokemon or PBV.")
  else
    PokeBattle.chatView.announce('success',
      "<b>PBV:</b> #{messages.join('; ')}")

findPokemonAtPBV = (pbv) ->
  messages = []
  counter = 0
  for speciesName, formes of window.Generations.XY.FormeData
    for formeName, formeData of formes
      if formeData.pokeBattleValue <= pbv
        counter += 1
        dexEntry = "pokemon/#{slugify(speciesName)}/#{slugify(formeName)}"
        icon = pokemonIcon(speciesName, formeName)
        formattedName = formatName(speciesName, formeName)
        messages.push("#{linkToDex(dexEntry, icon + formattedName)}:
          #{formeData.pokeBattleValue}")
  if messages.length > 10
    messages = _.sample(messages, 10)    
    messages.push(linkToDex("pokemon/?pbv=<#{pbv + 1}", 
      "See more Pokemon &raquo;"))    
  if messages.length > 0
    plural = if messages.length == 1 then "is" else "are"
    messages.unshift("There #{plural} #{counter} Pokemon with a PBV of
      #{pbv} or less")
  messages

findTotalPBV = (pokemon) ->
  pokemon = _(pokemon).map(findPokemon)
  messages = []
  total = 0
  for array in pokemon
    continue  unless array
    [speciesName, formeName] = array
    pbv = PokeBattle.PBV.determinePBV(window.Generations.XY,
      species: speciesName, forme: formeName)
    total += pbv
    dexEntry = "pokemon/#{slugify(speciesName)}/#{slugify(formeName)}"
    icon = pokemonIcon(speciesName, formeName)
    formattedName = formatName(speciesName, formeName)
    messages.push("#{linkToDex(dexEntry, icon + formattedName)}: #{pbv}")
  messages.push("Total: #{total}")  if messages.length > 1
  messages

desc 'Looks up information about a Pokemon, move, item, or ability.'
makeCommand "data", "dex", (query) ->
  if (pokemon = findPokemon(query))
    dataPokemon(pokemon)
  else if (item = findItem(query))
    dataItem(item)
  else if (move = findMove(query))
    dataMove(move)
  else if (ability = findAbility(query))
    dataAbility(ability)
  else
    PokeBattle.chatView.announce("error",
      "<b>Data error:</b> Enter a valid Pokemon, item, move, or ability.</div>")

dataPokemon = (pokemon) ->
  [speciesName, formeName] = pokemon
  [speciesSlug, formeSlug] = [slugify(speciesName), slugify(formeName)]
  forme = window.Generations.XY.FormeData[speciesName][formeName]
  {types, abilities, hiddenAbility, stats, pokeBattleValue} = forme

  # Format abilities
  abilities = _.clone(abilities)
  abilities.push(hiddenAbility)  if hiddenAbility?
  abilities = _(abilities).map((a) -> linkToDex("abilities/#{slugify(a)}", a))
  abilities = abilities.join('/')
  abilities += " (H)"  if hiddenAbility?

  # Format types, stats, and icon
  types = _(types).map (t) ->
    linkToDex("types/#{slugify(t)}",
      "<img src='#{window.TypeSprite(t)}' alt='#{t}'/>")
  stats = [ stats.hp, stats.attack, stats.defense,
            stats.specialAttack, stats.specialDefense, stats.speed ]

  # Build data
  message = """<b>#{pokemonIcon(speciesName, formeName, "left")}
    #{formatName(speciesName, formeName)}:</b> #{types.join('')} |
    #{abilities}<br />#{stats.join(' / ')} |
    #{_(stats).reduce((a, b) -> a + b)} BST | PBV: #{pokeBattleValue}
    #{linkToDex("pokemon/#{speciesSlug}/#{formeSlug}", "See dex entry &raquo;")}
    """
  PokeBattle.chatView.announce('success', message)

dataItem = (itemName) ->
  item = window.Generations.XY.ItemData[itemName]
  message = "<b>#{itemName}:</b> #{item.description}"
  message += " Natural Gift is #{item.naturalGift.type} type
    and has #{item.naturalGift.power} base power."  if item.naturalGift
  message += " Fling has #{item.flingPower} base power."  if item.flingPower
  message += " Currently unreleased in Gen 6."  if item.unreleased
  PokeBattle.chatView.announce('success', message)

dataMove = (moveName) ->
  move = window.Generations.XY.MoveData[moveName]
  type = linkToDex("types/#{slugify(move.type)}",
    "<img src='#{window.TypeSprite(move.type)}' alt='#{move.type}'/>")
  category = """<img src="#{CategorySprite(move.damage)}"
    alt="#{move.damage}"/>"""
  target = """<img src="#{TargetSprite(move)}"
    alt="#{move.target}"/>"""
  power = move.power || "&mdash;"
  acc = move.accuracy || "&mdash;"
  maxpp = Math.floor(move.pp * 8/5)
  if move.priority > 0
    priority = "+#{move.priority}"
  else if move.priority < 0
    priority = move.priority
  message = """<b>#{moveName}:</b> #{type} #{category} #{target} """
  message += "<b>Power:</b> #{power} <b>Acc:</b> #{acc} <b>PP:</b> #{move.pp} (max #{maxpp})"
  message += "<br />"
  message += "Priority #{priority}. "  if priority
  message += move.description
  message += " "
  message += linkToDex("moves/#{slugify(moveName)}",
    "See who learns this move &raquo;")
  PokeBattle.chatView.announce('success', message)

dataAbility = (abilityName) ->
  ability = window.Generations.XY.AbilityData[abilityName]
  message = """<b>#{abilityName}:</b> #{ability.description}
    #{linkToDex("abilities/#{slugify(abilityName)}",
      "See who obtains this ability &raquo;")}"""
  PokeBattle.chatView.announce('success', message)

# Finds the most lenient match possible.
findPokemon = (pokemonName) ->
  pokemonName = normalize(pokemonName)
  for speciesName, speciesData of window.Generations.XY.FormeData
    for formeName of speciesData
      name = speciesName
      name += formeName  unless formeName == 'default'
      name = normalize(name)
      name += name
      return [speciesName, formeName]  if name.indexOf(pokemonName) != -1
  # Return blank match
  null

# Finds the most lenient match possible.
findItem = (itemName) ->
  normalized = normalize(itemName)
  for name of window.Generations.XY.ItemData
    return name  if normalized == normalize(name)
  # Return blank match
  null

# Finds the most lenient match possible.
findMove = (moveName) ->
  normalized = normalize(moveName)
  for name of window.Generations.XY.MoveData
    return name  if normalized == normalize(name)
  # Return blank match
  null

# Finds the most lenient match possible.
findAbility = (abilityName) ->
  normalized = normalize(abilityName)
  for name of window.Generations.XY.AbilityData
    return name  if normalized == normalize(name)
  # Return blank match
  null

slugify = (str) ->
  str.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/\-{2,}/g, '-')

normalize = (str) ->
  str.trim().toLowerCase().replace(/[^a-zA-Z0-9]+/g, '')

formatName = (speciesName, formeName) ->
  if formeName == 'default'
    pokemonName = speciesName
  else
    pokemonName = speciesName
    pokemonName += ' '
    pokemonName += formeName.split('-')
      .map((n) -> n[0].toUpperCase() + n[1...])
      .join('-')
  return pokemonName

linkToDex = (slug, text) ->
  "<a href='//pokebattle.com/dex/#{slug}' target='_blank'>#{text}</a>"

pokemonIcon = (speciesName, formeName, classes="") ->
  style = window.PokemonIconBackground(speciesName, formeName)
  """<span class="pokemon_icon #{classes}" style="#{style}"></span>"""
