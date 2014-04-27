async = require 'async'
db = require './database'
@algorithm = require('./elo')

RATINGS_KEY = "ratings"
RATINGS_ATTRIBUTES = ['rating']
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
      object[attribute] = value
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

@updatePlayer = (id, object, next) ->
  multi = db.multi()
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
  exports.getPlayer id, (err, player) =>
    return next(err)  if err
    exports.getPlayer opponentId, (err, opponent) =>
      return next(err)  if err
      winnerMatches = [{opponent, score}]
      loserMatches = [{opponent: player, score: 1.0 - score}]
      newWinner = exports.algorithm.calculate(player, winnerMatches, systemConstant: GLICKO2_TAU)
      newLoser = exports.algorithm.calculate(opponent, loserMatches, systemConstant: GLICKO2_TAU)
      async.parallel [
        ((callback) => @updatePlayer(id, newWinner, callback))
        ((callback) => @updatePlayer(opponentId, newLoser, callback))
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
      array.push(username: r[i], score: r[i + 1])
    next(null, array)
