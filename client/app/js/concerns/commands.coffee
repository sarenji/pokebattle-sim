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
    [speciesName, formeName] = array
    if formeName == 'default'
      pokemonName = speciesName
    else
      pokemonName = speciesName
      pokemonName += ' '
      pokemonName += formeName.split('-')
        .map((n) -> n[0].toUpperCase() + n[1...])
        .join('-')
    pbv = PokeBattle.PBV.determinePBV(window.Generations.XY,
      name: speciesName, forme: formeName)
    total += pbv
    messages.push("#{pokemonName}: #{pbv}")
  messages.push("Total: #{total}")  if pokemon.length > 1
  PokeBattle.chatView.updateChat("<b>PBV:</b> #{messages.join(' | ')}")

# Finds the most lenient match possible.
findPokemon = (pokemonName) ->
  pokemonName = pokemonName.trim().toLowerCase().replace(/[^a-zA-Z0-9]+/g, '')
  for speciesName, speciesData of window.Generations.XY.FormeData
    for formeName of speciesData
      name = speciesName
      name += formeName  unless formeName == 'default'
      name = name.toLowerCase().replace(/[^a-zA-Z0-9]+/g, '')
      return [speciesName, formeName]  if pokemonName == name
  # Return last match
  [speciesName, formeName]
