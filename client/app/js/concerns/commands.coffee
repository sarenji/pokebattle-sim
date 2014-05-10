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
    messages.push("#{formatName(speciesName, formeName)}: #{pbv}")
  if messages.length == 0
    PokeBattle.chatView.updateChat("<b>PBV error:</b> Enter valid Pokemon.")
  else
    messages.push("Total: #{total}")  if messages.length > 1
    PokeBattle.chatView.updateChat("<b>PBV:</b> #{messages.join(' | ')}")

makeCommand "data", "dex", (pokemon) ->
  pokemon = findPokemon(pokemon)
  if pokemon.length == 0
    PokeBattle.chatView.updateChat("<b>Data error:</b> Enter a valid Pokemon.")
    return

  [speciesName, formeName] = pokemon
  [speciesSlug, formeSlug] = [slugify(speciesName), slugify(formeName)]
  forme = window.Generations.XY.FormeData[speciesName][formeName]
  {types, abilities, hiddenAbility, stats} = forme

  # Format abilities
  abilities.push(hiddenAbility)  if hiddenAbility?
  abilities = _(abilities).map (a) ->
    "<a href='//pokebattle.com/dex/abilities/#{slugify(a)}'
    target='_blank'>#{a}</a>"
  abilities = abilities.join('/')
  abilities += " (H)"  if hiddenAbility?

  # Format types, stats, and icon
  types = _(types).map (t) ->
    "<a href='//pokebattle.com/dex/types/#{slugify(t)}'
    target='_blank'><img src='#{window.TypeSprite(t)}' alt='#{t}'/></a>"
  stats = [ stats.hp, stats.attack, stats.defense,
            stats.specialAttack, stats.specialDefense, stats.speed ]
  style = window.PokemonIconBackground(speciesName, formeName)

  # Build data
  message = """<div class="alert alert-success clearfix">
      <b><span class="pokemon_icon left" style="#{style}"></span>
      #{formatName(speciesName, formeName)}:</b> #{types.join('')} |
      #{abilities} | #{stats.join('/')} |
      #{_(stats).reduce((a, b) -> a + b)} BST | <a target="_blank"
      href="//pokebattle.com/dex/pokemon/#{speciesSlug}/#{formeSlug}">
      See dex entry &raquo;</a>
    </div>"""
  PokeBattle.chatView.updateChat(message)

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
