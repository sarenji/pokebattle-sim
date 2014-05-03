redis = require './redis'
async = require 'async'
{_} = require 'underscore'
@algorithm = require('./elo')

USERS_RATED_KEY = "users:rated"
USERS_ACTIVE_KEY = "users:active"
RATINGS_KEY = "ratings"
RATINGS_ATTRIBUTES = Object.keys(@algorithm.createPlayer())
RATINGS_SUBKEYS = {}
for attribute in RATINGS_ATTRIBUTES
  RATINGS_SUBKEYS[attribute] = [RATINGS_KEY, attribute].join(':')
RATINGS_PER_PAGE = 15

ALGORITHM_OPTIONS =
  systemConstant: 0.2  # Glicko2 tau

@results =
  WIN  : 1
  DRAW : 0.5  # In earlier generations, it's possible to draw.
  LOSE : 0

@setActive = (idArray, next) ->
  console.log("Trying to set active: #{idArray}")
  console.log(require('util').inspect(idArray))
  idArray = [idArray]  unless _.isArray(idArray)
  idArray = idArray.map((id) -> id.toLowerCase())
  redis.sadd(USERS_ACTIVE_KEY, idArray, next)

RATIOS_KEY = 'ratios'
RATIOS_ATTRIBUTES = Object.keys(@results).map((key) -> key.toLowerCase())
RATIOS_SUBKEYS = {}
for attribute in RATIOS_ATTRIBUTES
  RATIOS_SUBKEYS[attribute] = [RATIOS_KEY, attribute].join(':')

@getPlayer = (id, next) ->
  id = id.toLowerCase()
  multi = redis.multi()
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
    return next(null, Number(player.rating))

@setRating = (id, newRating, next) ->
  id = id.toLowerCase()
  multi = redis.multi()
  multi = multi.sadd(USERS_RATED_KEY, id)
  multi = multi.zadd(RATINGS_SUBKEYS['rating'], newRating, id)
  multi.exec(next)

@setRatings = (idArray, newRatingArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  multi = redis.multi()
  multi = multi.sadd(USERS_RATED_KEY, idArray)
  for id, i in idArray
    newRating = newRatingArray[i]
    multi = multi.zadd(RATINGS_SUBKEYS['rating'], newRating, id)
  multi.exec(next)

@getPlayers = (idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  callbacks = idArray.map (id) =>
    (callback) => @getPlayer(id, callback)
  async.parallel(callbacks, next)

@getRatings = (idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  exports.getPlayers idArray, (err, players) ->
    return next(err)  if err
    return next(null, players.map((p) -> Number(p.rating)))

@updatePlayer = (id, score, object, next) ->
  id = id.toLowerCase()
  multi = redis.multi()
  attribute = switch score
    when 1 then 'win'
    when 0 then 'lose'
    else 'draw'
  multi = multi.hincrby(RATIOS_SUBKEYS[attribute], id, 1)
  multi = multi.sadd(USERS_RATED_KEY, id)
  for attribute in RATINGS_ATTRIBUTES
    value = object[attribute]
    multi = multi.zadd(RATINGS_SUBKEYS[attribute], value, id)
  multi.exec(next)

@updatePlayers = (id, opponentId, score, next) ->
  if score < 0 || score > 1
    return next(new Error("Invalid match result: #{score}"))

  id = id.toLowerCase()
  opponentId = opponentId.toLowerCase()
  opponentScore = 1.0 - score
  exports.getPlayers [id, opponentId], (err, results) =>
    return next(err)  if err
    [player, opponent] = results
    winnerMatches = [{opponent, score}]
    loserMatches = [{opponent: player, score: opponentScore}]
    newWinner = exports.algorithm.calculate(player, winnerMatches, ALGORITHM_OPTIONS)
    newLoser = exports.algorithm.calculate(opponent, loserMatches, ALGORITHM_OPTIONS)
    async.parallel [
      @updatePlayer.bind(this, id, score, newWinner)
      @updatePlayer.bind(this, opponentId, opponentScore, newLoser)
    ], (err, results) =>
      return next(err)  if err
      @getRatings([id, opponentId], next)


@resetRating = (id, next) ->
  @resetRatings([id], next)

@resetRatings = (idArray, next) ->
  idArray = idArray.map((id) -> id.toLowerCase())
  multi = redis.multi()
  multi = multi.srem(USERS_RATED_KEY, idArray)
  for attribute, key of RATINGS_SUBKEYS
    multi = multi.zrem(key, idArray)
  multi.exec(next)

@listRatings = (page = 1, perPage = RATINGS_PER_PAGE, next) ->
  if arguments.length == 2 && typeof perPage == 'function'
    [perPage, next] = [RATINGS_PER_PAGE, perPage]
  page -= 1
  start = page * perPage
  end = start + (perPage - 1)
  redis.zrevrange RATINGS_SUBKEYS['rating'], start, end, 'WITHSCORES', (err, r) ->
    return next?(err)  if err
    array = []
    for i in [0...r.length] by 2
      username = r[i]
      score = Number(r[i + 1])  # redis returns scores as strings
      array.push(username: username, score: score)
    next(null, array)

@getRatio = (id, next) ->
  id = id.toLowerCase()
  multi = redis.multi()
  for attribute, key of RATIOS_SUBKEYS
    multi = multi.hget(key, id)
  multi.exec (err, results) ->
    return next(err)  if err
    hash = {}
    for attribute, i in RATIOS_ATTRIBUTES
      hash[attribute] = Number(results[i]) || 0
    return next(null, hash)
