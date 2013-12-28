ratings = require('./ratings')
errors = require('../shared/errors')

Commands = {}

exports.Auth = Auth =
  USER          : 1
  DRIVER        : 2
  MOD           : 3
  MODERATOR     : 3
  ADMIN         : 4
  ADMINISTRATOR : 4
  OWNER         : 5

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
  func.authority = Auth.MOD
  makeCommand(commandNames, func)

makeAdminCommand = (commandNames, func) ->
  func.authority = Auth.ADMIN
  makeCommand(commandNames, func)

makeOwnerCommand = (commandNames, func) ->
  func.authority = Auth.OWNER
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
    user.error(errors.COMMAND_ERROR, "Usage: /kick [username]")
    return next()
  else if !room.has(username)
    user.error(errors.COMMAND_ERROR, "User #{username} is not online.")
    return next()
  room.kick(username)
  message = "#{@id} kicked #{username}"
  message += " (#{reason})"  if reason
  room.message(message)
  next()
