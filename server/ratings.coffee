async = require 'async'
db = require './database'
@algorithm = require('./glicko2')

RATINGS_KEY = "ratings"
RATINGS_ATTRIBUTES = ['rating', 'deviation', 'volatility']
RATINGS_SUBKEYS = {}
for attribute in RATINGS_ATTRIBUTES
  RATINGS_SUBKEYS[attribute] = [RATINGS_KEY, attribute].join(':')
RATINGS_PER_PAGE = 15

GLICKO2_TAU = .2

@results =
  WIN  : 1
  DRAW : 0.5  # In earlier generations, it's possible to draw.
  LOSE : 0

INVERSE_RESULTS =
  '1'   : "WIN"
  '0.5' : "DRAW"
  '0'   : "LOSE"

RATIOS_KEY = 'ratios'
RATIOS_ATTRIBUTES = Object.keys(@results).map((key) -> key.toLowerCase())
RATIOS_SUBKEYS = {}
for attribute in RATIOS_ATTRIBUTES
  RATIOS_SUBKEYS[attribute] = [RATIOS_KEY, attribute].join(':')

@getPlayer = (id, next) ->
  id = id.toLowerCase()
  multi = db.multi()
  for attribute in RATINGS_ATTRIBUTES
    multi = multi.zscore(RATINGS_SUBKEYS[attribute], id)
  multi.exec (err, results) ->
    return next(err)  if err
    object = {}
    for value, i in results
      attribute = RATINGS_ATTRIBUTES[i]
      value ||= exports.algorithm.createPlayer()[attribute]
      object[attribute] = parseFloat(value) # redis returns the value as a string, so parse it
    return next(null, object)

@getRating = (id, next) ->
  id = id.toLowerCase()
  exports.getPlayer id, (err, player) ->
    return next(err)  if err
    return next(null, player.rating)

@setRating = (id, newRating, next) ->
  id = id.toLowerCase()
  db.zadd(RATINGS_SUBKEYS['rating'], newRating, id, next)

@getPlayers = (idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  callbacks = idArray.map (id) =>
    (callback) => @getPlayer(id, callback)
  async.parallel(callbacks, next)

@getRatings = (idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  exports.getPlayers idArray, (err, players) ->
    return next(err)  if err
    return next(null, players.map((p) -> p.rating))

@updatePlayer = (id, score, object, next) ->
  multi = db.multi()
  attribute = INVERSE_RESULTS[score].toLowerCase()
  multi = multi.hincrby(RATIOS_SUBKEYS[attribute], id, 1)
  for attribute in RATINGS_ATTRIBUTES
    value = object[attribute]
    multi = multi.zadd(RATINGS_SUBKEYS[attribute], value, id)
  multi.exec (err, results) ->
    return next(err)  if err
    return next(null, object)

@updatePlayers = (id, opponentId, score, next) ->
  if score not of INVERSE_RESULTS
    return next(new Error("Invalid match result: #{score}"))

  id = id.toLowerCase()
  opponentId = opponentId.toLowerCase()
  opponentScore = 1.0 - score
  exports.getPlayer id, (err, player) =>
    return next(err)  if err
    exports.getPlayer opponentId, (err, opponent) =>
      return next(err)  if err
      winnerMatches = [{opponent, score}]
      loserMatches = [{opponent: player, score: opponentScore}]
      newWinner = exports.algorithm.calculate(player, winnerMatches, systemConstant: GLICKO2_TAU)
      newLoser = exports.algorithm.calculate(opponent, loserMatches, systemConstant: GLICKO2_TAU)
      async.parallel [
        ((callback) => @updatePlayer(id, score, newWinner, callback))
        ((callback) => @updatePlayer(opponentId, opponentScore, newLoser, callback))
      ], next

@resetRating = (id, next) ->
  @resetRatings([id], next)

@resetRatings = (idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  multi = db.multi()
  for attribute, key of RATINGS_SUBKEYS
    multi = multi.zrem(key, idArray)
  multi.exec(next)

@listRatings = (page = 1, perPage = RATINGS_PER_PAGE, next = ->) ->
  if arguments.length == 2 && typeof perPage == 'function'
    [perPage, next] = [RATINGS_PER_PAGE, perPage]
  page -= 1
  start = page * perPage
  end = start + (perPage - 1)
  db.zrevrange RATINGS_SUBKEYS['rating'], start, end, 'WITHSCORES', (err, r) ->
    return next(err)  if err
    array = []
    for i in [0...r.length] by 2
      username = r[i]
      score = parseFloat(r[i + 1])  # redis returns scores as strings
      array.push(username: username, score: score)
    next(null, array)

@getRatio = (id, next) ->
  id = id.toLowerCase()
  multi = db.multi()
  for attribute, key of RATIOS_SUBKEYS
    multi = multi.hget(key, id)
  multi.exec (err, results) ->
    return next(err)  if err
    hash = {}
    for attribute, i in RATIOS_ATTRIBUTES
      hash[attribute] = Number(results[i]) || 0
    return next(null, hash)
