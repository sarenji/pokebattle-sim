auth = require('./auth')
ratings = require('./ratings')
errors = require('../shared/errors')

Commands = {}

parseArguments = (args) ->
  args = Array::slice.call(args, 0)
  hash = {}
  if typeof args[args.length - 1] == 'function'
    hash.callback = args.pop()
  hash.args = args
  hash

makeCommand = (commandNames, func) ->
  commandNames = [ commandNames ]  if commandName not instanceof Array
  for commandName in commandNames
    Commands[commandName] = func

makeModCommand = (commandNames, func) ->
  func.authority = auth.levels.MOD
  makeCommand(commandNames, func)

makeAdminCommand = (commandNames, func) ->
  func.authority = auth.levels.ADMIN
  makeCommand(commandNames, func)

makeOwnerCommand = (commandNames, func) ->
  func.authority = auth.levels.OWNER
  makeCommand(commandNames, func)

@executeCommand = (user, room, commandName, args...) ->
  {args, callback} = parseArguments(args)
  callback ||= ->
  func = Commands[commandName]
  if !func
    message = "Invalid command: #{commandName}. Type /help to see a list."
    return user.error(errors.COMMAND_ERROR, message)
  if !func.authority || user.authority >= func.authority
    Commands[commandName]?.call(user, user, room, callback, args...)
  else
    user.error(errors.COMMAND_ERROR, "You have insufficient authority.")
    callback()

#######################
# Command definitions #
#######################

makeCommand "rating", (user, room, next, username) ->
  username ||= user.id
  ratings.getRating username, (err, rating) ->
    if err then return user.error(errors.COMMAND_ERROR, err.message)
    user.message("#{username}'s rating: #{rating}")
    next(err, {username, rating})

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

makeOwnerCommand "mod", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /mod username")
    return next()
  auth.setAuth username, auth.levels.MOD, (err, result) ->
    if err then return next(err)
    user = room.get(username)
    user.setAuthority(auth.levels.MOD)
    return next(null, result)
