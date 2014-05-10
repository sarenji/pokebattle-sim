PokeBattle.commands ?= {}

Commands = {}

makeCommand = (commandNames..., func) ->
  for commandName in commandNames
    Commands[commandName] = func

parseCommand = (line) ->
  [ commandName, args... ] = line.split(/\s+/)
  if commandName[0] == '/' && commandName[1] != '/'
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

makeCommand "challenge", "chall", "c", (username) ->
  if !username
    PokeBattle.events.trigger("error", "Usage: /challenge username")
    return
  message = PokeBattle.messages.add(id: username)
  message.openChallenge(username)

makeCommand "message", "msg", "pm", "whisper", "w", (username, messages...) ->
  username = username?.trim()
  if !username
    PokeBattle.events.trigger("error", "Usage: /message user name[, message]")
    return
  message = PokeBattle.messages.add(id: username)

  if messages.length > 0
    text = messages.join(',')
    PokeBattle.socket.send('privateMessage', message.id, text)
    message.add("Me", text)
  else
    # The PM is opened without a message.
    message.trigger('open', message)

makeCommand "clear", ->
  PokeBattle.chatView.clear()

makeCommand "pbv", (pokemon...) ->
  pokemon = _(pokemon).map(findPokemon)
  messages = []
  total = 0
  for array in pokemon
    continue  if array.length == 0
    [speciesName, formeName] = array
    pbv = PokeBattle.PBV.determinePBV(window.Generations.XY,
      name: speciesName, forme: formeName)
    total += pbv
    dexEntry = "pokemon/#{slugify(speciesName)}/#{slugify(formeName)}"
    icon = pokemonIcon(speciesName, formeName)
    formattedName = formatName(speciesName, formeName)
    messages.push("#{linkToDex(dexEntry, icon + formattedName)}: #{pbv}")
  if messages.length == 0
    PokeBattle.chatView.announce('error',
      "<b>PBV error:</b> Enter valid Pokemon.")
  else
    messages.push("Total: #{total}")  if messages.length > 1
    PokeBattle.chatView.announce('success',
      "<b>PBV:</b> #{messages.join(' | ')}")

makeCommand "data", "dex", (pokemon) ->
  pokemon = findPokemon(pokemon)
  if pokemon.length == 0
    PokeBattle.chatView.announce("error",
      "<b>Data error:</b> Enter a valid Pokemon.</div>")
    return

  [speciesName, formeName] = pokemon
  [speciesSlug, formeSlug] = [slugify(speciesName), slugify(formeName)]
  forme = window.Generations.XY.FormeData[speciesName][formeName]
  {types, abilities, hiddenAbility, stats} = forme

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
    #{abilities} | #{stats.join('/')} |
    #{_(stats).reduce((a, b) -> a + b)} BST |
    #{linkToDex("pokemon/#{speciesSlug}/#{formeSlug}", "See dex entry &raquo;")}
    """
  PokeBattle.chatView.announce('success', message)

# Finds the most lenient match possible.
findPokemon = (pokemonName) ->
  pokemonName = pokemonName.trim().toLowerCase().replace(/[^a-zA-Z0-9]+/g, '')
  for speciesName, speciesData of window.Generations.XY.FormeData
    for formeName of speciesData
      name = speciesName
      name += formeName  unless formeName == 'default'
      name = name.toLowerCase().replace(/[^a-zA-Z0-9]+/g, '')
      return [speciesName, formeName]  if pokemonName == name
  # Return blank match
  []

slugify = (str) ->
  str.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/\-{2,}/g, '-')

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
