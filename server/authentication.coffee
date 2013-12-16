request = require 'request'
{_} = require 'underscore'
authHeaders = {AUTHUSER: process.env.AUTHUSER, AUTHTOKEN: process.env.AUTHTOKEN}
request = request.defaults(json: true, headers: authHeaders)

config = require './config'
db = require './database'

@middleware = -> (req, res, next) ->
  auth req.cookies.sessionid, (body) ->
    if !body
      redirectURL = "http://pokebattle.com/accounts/login"
      redirectURL += "?next=http://#{req.headers.host}"
      return res.redirect(redirectURL)
    req.user = _.clone(body)
    req.user.token = generateToken()
    db.set "tokens:#{req.user.token}", JSON.stringify(body), (err) ->
      if err then return next.apply(null, arguments)
      db.expire("tokens:#{req.user.token}", 5 * 60)  # Expire in 5 mins.
      next.apply(null, arguments)

@auth = auth = (id, next) ->
  return next(username: generateUsername())  if config.IS_LOCAL
  return next()  if !id
  request.get "http://pokebattle.com/api/v1/user/#{id}", (err, res, body) ->
    return next()  if err
    return next(body)

@matchToken = (token, next) ->
  db.get "tokens:#{token}", (err, result) ->
    db.del("tokens:#{token}")  # We don't need the token anymore.
    if err then return next(err, null)
    user = JSON.parse(result)
    return next(null, user)

generateUsername = ->
  {SpeciesData} = require './xy/data'
  randomName = (name  for name of SpeciesData)
  randomName = randomName[Math.floor(Math.random() * randomName.length)]
  randomName = randomName.split(/\s+/)[0]
  randomName += "Fan" + Math.floor(Math.random() * 10000)
  randomName

generateToken = ->
  Math.random().toString(36).substr(2)
