{_} = require 'underscore'

crypto = require('crypto')

request = require 'request'
authHeaders = {AUTHUSER: process.env.AUTHUSER, AUTHTOKEN: process.env.AUTHTOKEN}
request = request.defaults(json: true, headers: authHeaders, timeout: 30 * 1000)

config = require './config'
redis = require './redis'

USER_KEY = "users"
AUTH_KEY = "auth"
BANS_KEY = "bans"
MUTE_KEY = "mute"

# This middleware checks if a user is authenticated through the site. If yes,
# then information about the user is stored in req.user. In addition, we store
# a token associated with that user into req.user.token.
#
# User information is also stored in redis.
exports.middleware = -> (req, res, next) ->
  return next()  if req.path.match(/^\/css|^\/js|^\/fonts/)
  return next()  if req.path == '/leaderboard'  # add some proper site authentication later instead

  authenticate req, (body) ->
    if !body
      redirectURL = "https://forum.pokebattle.com/session/sso"
      redirectURL += "?return_path=https://sim.pokebattle.com"
      return res.redirect(redirectURL)
    # The remote URL returns `username`, but we'd like a more unified interface,
    # so we replace `username` with `name`.
    body.name = body.username
    delete body.username

    req.user = _.clone(body)
    hmac = crypto.createHmac('sha256', config.SECRET_KEY)
    req.user.token = hmac.update("#{req.user.id}").digest('hex')
    redis.shard('hset', USER_KEY, req.user.id, JSON.stringify(body), next)

# If the id and token match, the associated user object is returned.
exports.matchToken = (id, token, next) ->
  hmac = crypto.createHmac('sha256', config.SECRET_KEY)
  if hmac.update("#{id}").digest('hex') != token
    return next(new Error("Invalid session!"))
  redis.shard 'hget', USER_KEY, id, (err, jsonString) ->
    if err then return next(err)
    json = JSON.parse(jsonString)
    return next(new Error("Invalid session!"))  if !json
    exports.getAuth json.name, (err, authLevel) ->
      if err then return next(err)
      json.authority = authLevel
      return next(null, json)

# Authenticates against the site. A user object is returned if successful, or
# null if unsuccessful.
authenticate = (req, next) ->
  id = req.cookies.sessionid
  return next(generateUser(req))  if config.IS_LOCAL
  return next()  if !id
  request.get "https://pokebattle.com/api/v1/user/#{id}", (err, res, body) ->
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

generateId = (req) ->
  req.param('id') || Math.floor(1000000 * Math.random())

generateUser = (req) ->
  {id: generateId(req), username: generateUsername(req)}


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
  id = String(id).toLowerCase()
  redis.hget AUTH_KEY, id, (err, auth) ->
    if err then return next(err)
    auth = parseInt(auth, 10) || exports.levels.USER
    next(null, auth)

exports.setAuth = (id, newAuthLevel, next) ->
  id = String(id).toLowerCase()
  if newAuthLevel not in LEVEL_VALUES
    next(new Error("Incorrect auth level: #{newAuthLevel}"))
  redis.hset(AUTH_KEY, id, newAuthLevel, next)

# Ban
# Length is in seconds.
exports.ban = (id, reason, length, next) ->
  id = id.toLowerCase()
  key = "#{BANS_KEY}:#{id}"
  if length > 0
    redis.setex(key, length, reason, next)
  else
    redis.set(key, reason, next)

exports.unban = (id, next) ->
  id = String(id).toLowerCase()
  redis.del("#{BANS_KEY}:#{id}", next)

exports.getBanReason = (id, next) ->
  id = String(id).toLowerCase()
  redis.get("#{BANS_KEY}:#{id}", next)

exports.getBanTTL = (id, next) ->
  id = String(id).toLowerCase()
  key = "#{BANS_KEY}:#{id}"
  redis.exists key, (err, result) ->
    if !result
      # In older versions of Redis, TTL returns -1 if key doesn't exist.
      return next(null, -2)
    else
      redis.ttl(key, next)

# Mute
# Length is in seconds.
exports.mute = (id, reason, length, next) ->
  id = String(id).toLowerCase()
  key = "#{MUTE_KEY}:#{id}"
  if length > 0
    redis.setex(key, length, reason, next)
  else
    redis.set(key, reason, next)

exports.unmute = (id, next) ->
  id = String(id).toLowerCase()
  key = "#{MUTE_KEY}:#{id}"
  redis.del(key, next)

exports.getMuteTTL = (id, next) ->
  id = String(id).toLowerCase()
  key = "#{MUTE_KEY}:#{id}"
  redis.exists key, (err, result) ->
    if !result
      # In older versions of Redis, TTL returns -1 if key doesn't exist.
      return next(null, -2)
    else
      redis.ttl(key, next)
