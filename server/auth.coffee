{_} = require 'underscore'

crypto = require('crypto')

request = require 'request'
authHeaders = {AUTHUSER: process.env.AUTHUSER, AUTHTOKEN: process.env.AUTHTOKEN}
request = request.defaults(json: true, headers: authHeaders)

config = require './config'
db = require './database'

USER_KEY = "users"
AUTH_KEY = "auth"
BANS_KEY = "bans"
MUTE_KEY = "mute"

# This middleware checks if a user is authenticated through the site. If yes,
# then information about the user is stored in req.user. In addition, we store
# a token associated with that user into req.user.token.
#
# User information is also stored in a database.
exports.middleware = -> (req, res, next) ->
  authenticate req, (body) ->
    if !body
      redirectURL = "http://pokebattle.com/accounts/login"
      redirectURL += "?next=/sim"
      return res.redirect(redirectURL)
    req.user = _.clone(body)
    hmac = crypto.createHmac('sha256', config.SECRET_KEY)
    req.user.token = hmac.update("#{req.user.id}").digest('hex')
    db.hset(USER_KEY, body.id, JSON.stringify(body), next)

# If the id and token match, the associated user object is returned.
exports.matchToken = (id, token, next) ->
  hmac = crypto.createHmac('sha256', config.SECRET_KEY)
  if hmac.update("#{id}").digest('hex') != token
    return next(new Error("Invalid session!"))
  db.hget USER_KEY, id, (err, jsonString) ->
    if err then return next(err)
    json = JSON.parse(jsonString)
    return next(new Error("Invalid session!"))  if !json
    exports.getAuth json.username, (err, authLevel) ->
      if err then return next(err)
      json.authority = authLevel
      return next(null, json)

# Authenticates against the site. A user object is returned if successful, or
# null if unsuccessful.
authenticate = (req, next) ->
  id = req.cookies.sessionid
  return next(generateUser(req))  if config.IS_LOCAL
  return next()  if !id
  request.get "http://pokebattle.com/api/v1/user/#{id}", (err, res, body) ->
    return next()  if err || res.statusCode != 200
    return next(body)

generateUsername = (req) ->
  name = req.param('user')
  return name  if name
  {SpeciesData} = require './xy/data'
  randomName = (name  for name of SpeciesData)
  randomName = randomName[Math.floor(Math.random() * randomName.length)]
  randomName = randomName.split(/\s+/)[0]
  randomName += "Fan" + Math.floor(Math.random() * 10000)
  randomName

generateId = ->
  Math.floor(1000000 * Math.random())

generateUser = (req) ->
  {id: generateId(), username: generateUsername(req)}


# Authorization

exports.levels =
  USER          : 1
  DRIVER        : 2
  MOD           : 3
  MODERATOR     : 3
  ADMIN         : 4
  ADMINISTRATOR : 4
  OWNER         : 5

LEVEL_VALUES = (value  for key, value of exports.levels)

exports.getAuth = (id, next) ->
  id = id.toLowerCase()
  db.hget AUTH_KEY, id, (err, auth) ->
    if err then return next(err)
    auth = parseInt(auth, 10) || exports.levels.USER
    next(null, auth)

exports.setAuth = (id, newAuthLevel, next) ->
  id = id.toLowerCase()
  if newAuthLevel not in LEVEL_VALUES
    next(new Error("Incorrect auth level: #{newAuthLevel}"))
  db.hset(AUTH_KEY, id, newAuthLevel, next)

# Ban
# Length is in seconds.
exports.ban = (username, reason, length, next) ->
  username = username.toLowerCase()
  key = "#{BANS_KEY}:#{username}"
  if length > 0
    db.setex(key, length, reason, next)
  else
    db.set(key, reason, next)

exports.unban = (username, next) ->
  username = username.toLowerCase()
  db.del("#{BANS_KEY}:#{username}", next)

exports.getBanReason = (username, next) ->
  username = username.toLowerCase()
  db.get("#{BANS_KEY}:#{username}", next)

exports.getBanTTL = (username, next) ->
  username = username.toLowerCase()
  key = "#{BANS_KEY}:#{username}"
  db.exists key, (err, result) ->
    if !result
      # In older versions of Redis, TTL returns -1 if key doesn't exist.
      return next(null, -2)
    else
      db.ttl(key, next)

# Mute
# Length is in seconds.
exports.mute = (username, reason, length, next) ->
  username = username.toLowerCase()
  key = "#{MUTE_KEY}:#{username}"
  if length > 0
    db.setex(key, length, reason, next)
  else
    db.set(key, reason, next)

exports.unmute = (username, next) ->
  username = username.toLowerCase()
  key = "#{MUTE_KEY}:#{username}"
  db.del(key, next)

exports.getMuteTTL = (username, next) ->
  username = username.toLowerCase()
  key = "#{MUTE_KEY}:#{username}"
  db.exists key, (err, result) ->
    if !result
      # In older versions of Redis, TTL returns -1 if key doesn't exist.
      return next(null, -2)
    else
      db.ttl(key, next)
