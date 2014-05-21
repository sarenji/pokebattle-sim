{_} = require('underscore')
async = require('async')
alts = require('./alts')
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

# Returns a 2-tuple, where the first element is the length (null for no length)
# and the second element is the reason.
parseLengthAndReason = (reasons) ->
  length = null
  possibleLength = reasons[0].trim()
  if /^[\dmshdyMw]+$/.test(possibleLength)
    length = parseLength(possibleLength)
    reasons = reasons[1...]
  return [length, reasons.join(',').trim()]

parseLength = (length) ->
  time = 0
  for member in length.match(/\d+[mshdyMw]?/g)
    first = parseInt(member, 10)  # Truncates any letter after the number
    last  = member.substr(-1)
    switch last
      when 's'
        time += first
      when 'h'
        time += first * 60 * 60
      when 'd'
        time += first * 60 * 60 * 24
        break;
      when 'w'
        time += first * 60 * 60 * 24 * 7
      when 'M'
        time += first * 60 * 60 * 24 * 30
      when 'y'
        time += first * 60 * 60 * 24 * 30 * 12
      else  # minutes by default
        time += first * 60 * 60
  return time

prettyPrintTime = (minutes) ->
  units = ["minute", "hour", "day", "week", "month", "year"]
  intervals = [60, 24, 7, 4, 12, Infinity]
  times = []
  minutes *= 60
  for interval, i in intervals
    remainder = (minutes % interval)
    minutes = Math.floor(minutes / interval)
    break  if minutes == 0
    unit = units[i]
    unit += 's'  if unit != 1
    times.push("#{remainder} #{unit}")
  return times.join(", ")

makeCommand = (commandNames..., func) ->
  authority = func.authority || auth.levels.USER
  HelpDescriptions[authority] ?= {}
  for commandName in commandNames
    Commands[commandName] = func

  # Generate description
  description = ""
  if commandNames.length > 1
    aliases = commandNames[1...].map((n) -> "/#{n}").join(', ')
    description += " <i>Also #{aliases}. </i>"
  description += desc.lastDescription
  HelpDescriptions[authority][commandNames[0]] = description
  delete desc.lastDescription

makeModCommand = (commandNames..., func) ->
  func.authority = auth.levels.MOD
  makeCommand(commandNames..., func)

makeAdminCommand = (commandNames..., func) ->
  func.authority = auth.levels.ADMIN
  makeCommand(commandNames..., func)

makeOwnerCommand = (commandNames..., func) ->
  func.authority = auth.levels.OWNER
  makeCommand(commandNames..., func)

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
makeCommand "rating", "ranking", "rank", (user, room, next, username) ->
  username ||= user.id
  async.parallel [
    ratings.getRating.bind(ratings, username)
    ratings.getRank.bind(ratings, username)
    ratings.getRatio.bind(ratings, username)
  ], (err, results) ->
    return user.error(errors.COMMAND_ERROR, err.message)  if err
    [rating, rank, ratios] = results
    ratio = []
    rank ?= "Unranked"
    ratio.push("Rank: #{rank}")
    ratio.push("Win: #{ratios.win}")
    if user.id == username
      total = _.reduce(_.values(ratios), ((x, y) -> x + y), 0)
      ratio.push("Lose: #{ratios.lose}")
      ratio.push("Tie: #{ratios.draw}")
      ratio.push("Total: #{total}")
    user.announce('success', "#{username}'s rating: #{rating} (#{ratio.join(' / ')})")
    next()

desc "Finds all the battles a username is playing in on this server.
      Usage: /battles username"
makeCommand "battles", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /battles username")
    return next()
  battleIds = @getVisibleUserBattles(username)
  links = battleIds.map (id) ->
    "<span class='fake_link spectate' data-battle-id='#{id}'>#{id[...6]}</span>"
  message = if battleIds.length == 0
      "#{username} is not playing any battles."
    else
      "#{username}'s battles: #{links.join(" | ")}"
  user.announce('success', message)
  next()

desc "Default length is 10 minutes, up to a maximum of two days. To specify different lengths, use 1m2h3d4w (minute, hour, day, week). Usage: /mute username, length, reason"
makeModCommand "mute", (user, room, next, username, reason...) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /mute username, reason")
    return next()
  [length, reason] = parseLengthAndReason(reason)
  length = 10 * 60  if !length? || length <= 0
  length = Math.min(parseLength("2d"), length)  # max of two days
  @mute(username, reason, length)
  message = "#{user.id} muted #{username} for #{prettyPrintTime(length)}"
  message += " (#{reason})"  if reason.length > 0
  room.announce('warning', message)
  next()

desc "Unmutes a username. Usage: /unmute username"
makeModCommand "unmute", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /unmute username")
    return next()
  auth.getMuteTTL username, (err, ttl) =>
    if ttl == -2
      user.error(errors.COMMAND_ERROR, "#{username} is already unmuted!")
      return next()
    else
      @unmute(username)
      message = "#{user.id} unmuted #{username}"
      room.announce('warning', message)
      next()

desc "Kicks a username for 3 minutes. The reason is optional. Usage: /kick username, reason"
makeModCommand "kick", (user, room, next, username, reason...) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /kick username,reason")
    return next()
  else if !room.has(username)
    user.error(errors.COMMAND_ERROR, "User #{username} is not online.")
    return next()
  reason = reason.join(',').trim()
  @ban(username, reason, 3 * 60)
  message = "#{user.id} kicked #{username} for 3 minutes"
  message += " (#{reason})"  if reason.length > 0
  room.announce('warning', message)
  next()

desc "Default length is one hour, up to a maximum of one day. To specify different lengths, use 1m2h3d (minute, hour, day). Usage: /ban username, length, reason"
makeModCommand "ban", (user, room, next, username, reason...) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /ban username, reason")
    return next()
  [length, reason] = parseLengthAndReason(reason)
  length = 60 * 60  if !length? || length <= 0
  length = Math.min(parseLength("1d"), length)  # max of one day
  @ban(username, reason, length)
  message = "#{user.id} banned #{username} for #{prettyPrintTime(length)}"
  message += " (#{reason})"  if reason.length > 0
  room.announce('warning', message)
  next()

desc "Unbans a username. Usage: /unban username"
makeModCommand "unban", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /unban username")
    return next()
  auth.getBanTTL username, (err, ttl) =>
    if ttl == -2
      user.error(errors.COMMAND_ERROR, "#{username} is already unbanned!")
      return next()
    else
      @unban username, =>
        message = "#{user.id} unbanned #{username}"
        room.announce('warning', message)
        return next()

desc "Prevents new battles from starting. Usage: /lockdown [on|off]"
makeAdminCommand "lockdown", (user, room, next, option = "on") ->
  if option not in [ "on", "off" ]
    user.error(errors.COMMAND_ERROR, "Usage: /lockdown [on|off]")
    return next()
  if option == 'on' then @lockdown() else @unlockdown()
  next()

desc "Drivers a username permanently. Usage: /driver username"
makeAdminCommand "driver", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /driver username")
    return next()
  auth.setAuth username, auth.levels.DRIVER, (err, result) =>
    if err
      user.error(errors.COMMAND_ERROR, err.message)
      return next()
    @setAuthority(username, auth.levels.DRIVER)
    return next()

desc "Mods a username permanently. Usage: /mod username"
makeAdminCommand "mod", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /mod username")
    return next()
  auth.setAuth username, auth.levels.MOD, (err, result) =>
    if err
      user.error(errors.COMMAND_ERROR, err.message)
      return next()
    @setAuthority(username, auth.levels.MOD)
    return next()

desc "Admins a username permanently. Usage: /admin username"
makeOwnerCommand "admin", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /admin username")
    return next()
  auth.setAuth username, auth.levels.ADMIN, (err, result) =>
    if err
      user.error(errors.COMMAND_ERROR, err.message)
      return next()
    @setAuthority(username, auth.levels.ADMIN)
    return next()

desc "Deauthes a username permanently. Usage: /deauth username"
makeOwnerCommand "deauth", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /deauth username")
    return next()
  auth.setAuth username, auth.levels.USER, (err, result) =>
    if err
      user.error(errors.COMMAND_ERROR, err.message)
      return next()
    @setAuthority(username, auth.levels.USER)
    return next()

desc "Changes the topic message. Usage: /topic message"
makeAdminCommand "topic", (user, room, next, topicPieces...) ->
  room.setTopic(topicPieces.join(','))
  next()

desc "Announces something to the entire server. Usage: /wall message"
makeModCommand "wall", "announce", (user, room, next, pieces...) ->
  message = pieces.join(',')
  return next()  if !message
  @announce("<strong>#{user.id}:</strong> #{message}")
  next()

desc "Finds all alts associated with a username, or the main username of an alt"
makeModCommand "whois", (user, room, next, username) ->
  if !username
    user.error(errors.COMMAND_ERROR, "Usage: /whois username")
    return next()

  messages = []
  alts.getAltOwner username, (err, ownerName) ->
    if err
      user.error(errors.COMMAND_ERROR, err.message)
      return next()
    ownerName ?= username
    messages.push("<b>Main account:</b> #{ownerName}")
    alts.listUserAlts username, (err, alts) ->
      if err
        user.error(errors.COMMAND_ERROR, err.message)
        return next()
      messages.push("<b>Alts:</b> #{alts.join(', ')}")  if alts.length > 0
      user.announce('success', messages.join(' | '))
      return next()

desc "Evaluates a script in the context of the server."
makeOwnerCommand "eval", (user, room, next, pieces...) ->
  source = pieces.join(',')
  return next()  if !source
  try
    result = (new Function("with(this) { return #{source} }")).call(this)
    user.announce('success', "> #{result}")
  catch e
    user.error(errors.COMMAND_ERROR, "EVAL ERROR: #{e.message}")
  next()
