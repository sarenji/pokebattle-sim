config = require './config'
request = require 'request'
authHeaders = {AUTHUSER: process.env.AUTHUSER, AUTHTOKEN: process.env.AUTHTOKEN}
request = request.defaults(json: true, headers: authHeaders)

@middleware = -> (req, res, next) ->
  auth req.cookies.sessionid, (body) ->
    if !body
      redirectURL = "http://pokebattle.com/accounts/login"
      redirectURL += "?next=http://#{req.headers.host}"
      return res.redirect(redirectURL)
    req.user = {username: body.username}
    next()

@auth = auth = (id, next) ->
  return next(username: generateUsername())  if config.IS_LOCAL
  return next()  if !id
  request.get "http://pokebattle.com/api/v1/user/#{id}", (err, res, body) ->
    return next()  if err
    console.log(body)
    return next(body)

generateUsername = ->
  {SpeciesData} = require './xy/data'
  randomName = (name  for name of SpeciesData)
  randomName = randomName[Math.floor(Math.random() * randomName.length)]
  randomName = randomName.split(/\s+/)[0]
  randomName += "Fan" + Math.floor(Math.random() * 10000)
  randomName
