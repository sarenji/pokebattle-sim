auth = require('./auth')
ratings = require('./ratings')
errors = require('../shared/errors')

exports.Commands = Commands = {}
exports.HelpDescriptions = HelpDescriptions = {}

desc = (description) ->
  desc.lastDescription = description

parseArguments = (args) ->
  args = Array::slice.call(args, 0)
  hash = {}
  if typeof args[args.length - 1] == 'function'
    hash.callback = args.pop()
  hash.args = args
  hash

makeCommand = (commandNames, func) ->
  commandNames = [ commandNames ]  if commandName not instanceof Array
  HelpDescriptions[commandNames[0]] = desc.lastDescription || ""
  for commandName in commandNames
    Commands[commandName] = func
  delete desc.lastDescription

makeModCommand = (commandNames, func) ->
  func.authority = auth.levels.MOD
  makeCommand(commandNames, func)

makeAdminCommand = (commandNames, func) ->
  func.authority = auth.levels.ADMIN
  makeCommand(commandNames, func)

makeOwnerCommand = (commandNames, func) ->
  func.authority = auth.levels.OWNER
  makeCommand(commandNames, func)

@executeCommand = (server, user, room, commandName, args...) ->
  {args, callback} = parseArguments(args)
  callback ||= ->
  func = Commands[commandName]
  if !func
    message = "Invalid command: #{commandName}. Type /help to see a list."
    user.error(errors.COMMAND_ERROR, message)
    callback()
  else if !func.authority || user.authority >= func.authority
    Commands[commandName]?.call(server, user, room, callback, args...)
  else
    user.error(errors.COMMAND_ERROR, "You have insufficient authority.")
    callback()

#######################
# Command definitions #
#######################

desc "Gets a single username's rating on this server. Usage: /rating username"
makeCommand "rating", (user, room, next, username) ->
  username ||= user.id
  ratings.getRating username, (err, rating) ->
    if err then return user.error(errors.COMMAND_ERROR, err.message)
    user.message("#{username}'s rating: #{rating}")
    next(err, {username, rating})

desc "Finds all the battles a username is playing in on this server.
      Usage: /battles username"
makeCommand "battles", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /battles username")
    return next(new Error("Incorrect usage"))
  battleIds = @getUserBattles(username)
  links = battleIds.map (id) ->
    "<span class='fake_link spectate' data-battle-id='#{id}'>#{id[...6]}</span>"
  user.message("#{username}'s battles: #{links.join(" | ")}")
  next(null, battleIds)

desc "Kicks a username. The reason is optional. Usage: /kick username [reason]"
makeModCommand "kick", (user, room, next, username, reason) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /kick username [reason]")
    return next()
  else if !room.has(username)
    user.error(errors.COMMAND_ERROR, "User #{username} is not online.")
    return next()
  room.kick(username)
  message = "#{@id} kicked #{username}"
  message += " (#{reason})"  if reason
  room.message(message)
  next()

desc "Mods a username permanently. Usage: /mod username"
makeOwnerCommand "mod", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /mod username")
    return next()
  auth.setAuth username, auth.levels.MOD, (err, result) ->
    if err then return next(err)
    user = room.get(username)
    user?.setAuthority(auth.levels.MOD)
    return next(null, result)

desc "Admins a username permanently. Usage: /admin username"
makeOwnerCommand "admin", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /admin username")
    return next()
  auth.setAuth username, auth.levels.ADMIN, (err, result) ->
    if err then return next(err)
    user = room.get(username)
    user?.setAuthority(auth.levels.ADMIN)
    return next(null, result)

desc "Deauthes a username permanently. Usage: /deauth username"
makeOwnerCommand "deauth", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /deauth username")
    return next()
  auth.setAuth username, auth.levels.USER, (err, result) ->
    if err then return next(err)
    user = room.get(username)
    user?.setAuthority(auth.levels.USER)
    return next(null, result)

desc "Changes the topic message. Usage: /topic message"
makeAdminCommand "topic", (user, room, next, topicPieces...) ->
  room.setTopic(topicPieces.join(','))
  next()

desc "Displays all commands available. Usage: /help"
makeCommand "help", (user, room, next, commandName) ->
  message = []
  for name, description of HelpDescriptions
    message.push(description)
  message = message.join("<br>")
  user.message(message)
  next(null, message)
