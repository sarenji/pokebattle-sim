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
