makeCommand = (commandName, func) ->

PokeBattle.commands ?= {}

PokeBattle.commands.parse = (line) ->
  [commandName, args] = line.split(/\s+/g, 2)
  if commandName[0] == '/' && commandName[1] != '/'
    # It's a command. Remove leading slash
    commandName = commandName[1...]
    return [commandName, args]
  return null

PokeBattle.commands.execute = (room, line) ->
  result = PokeBattle.commands.parse(line)
  if !result then return
  [commandName, args] = result
  command = Commands[commandName]
  if !command
    # Fall-through to server.
    return false
  command(room, args...)
  return true

makeCommand "challenge", (room, username) ->
  if !username
    PokeBattle.events.trigger("error", "Usage: /challenge username")
    return
  PokeBattle.popups.add
    type: "challenge"
    username: username
    params:
      title: "Challenge #{username}"

# What about _receiving_ a challenge? it should be the same, yes ...
# You cannot replicate received challenges.
