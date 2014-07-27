# Handles giving achievements to players
# Due to time constraints, this was rushed and not very generalized. This module can be expanded
# on in the future.

{_} = require 'underscore'
config = require './config'
redis = require './redis'
ratings = require './ratings'
{Conditions} = require '../shared/conditions'

request = require 'request'
authHeaders = {AUTHUSER: process.env.AUTHUSER, AUTHTOKEN: process.env.AUTHTOKEN}
request = request.defaults(json: true, headers: authHeaders, timeout: 30 * 1000)

ACHIEVEMENT_KEY = 'achievements'

winCount = (count) ->
  inner = (ratioData, streakData) ->
    ratioData.win >= count
  return inner

streak = (count) ->
  inner = (ratioData, streakData) ->
    streakData.streak >= count
  return inner

ACHIEVEMENTS = [
  {
    id: 1
    name: "Taste of Victory"
    condition: "Win on PokeBattle for the first time"
    conditionFn: winCount(1)
  },
  {
    id: 2
    name: "Centurian"
    condition: "Win 100 times"
    conditionFn: winCount(100)
  },
  {
    id: 3
    name: "Jackpot!"
    condition: "Lucky 777 victories"
    conditionFn: winCount(777)
  },
  {
    id: 4
    name: "Ladder Monster"
    condition: "Win a beastly 2500 matches"
    conditionFn: winCount(2500)
  },
  {
    id: 5
    name: "Mile High Club"
    condition: "Win 52"
    conditionFn: winCount(5280)
  },
  {
    id: 6
    name: "Better than Phil"
    condition: "More than 7086 victories"
    conditionFn: winCount(7087)
  },
  {
    id: 7
    name: "KAKAROT!"
    condition: "What? More than 9000 victories?!"
    conditionFn: winCount(9001)
  },

  # ladder ranking achievements go here

  {
    id: 26
    name: "On a Roll!"
    condition: "Five in a row"
    conditionFn: streak(5)
  },
  {
    id: 27
    name: "Perfect Ten!"
    condition: "10 in a row, very nice"
    conditionFn: streak(10)
  },
  {
    id: 28
    name: "Incredible!"
    condition: "15 victories!"
    conditionFn: streak(15)
  },
  {
    id: 29
    name: "Unreal!"
    condition: "20 victories in a row"
    conditionFn: streak(20)
  },
  {
    id: 30
    name: "Impossible!"
    condition: "30 victories! Hopefully counting"
    conditionFn: streak(30)
  },
  {
    id: 31
    name: "The One"
    condition: "50 in a row! PS: I love you <3"
    conditionFn: streak(50)
  }
]

# Returns the achievements a player is eligible for, including already earned ones
# id is the rating key used to identify the player
checkAchievements = (id, next) ->
  ratings.getRatio id, (err, ratio) ->
    ratings.getStreak id, (err, streak) ->
      achievements = ACHIEVEMENTS.filter((o) -> o.conditionFn(ratio, streak))

      # Send everything except the conditionFn attribute
      results = (_(a).omit('conditionFn')  for a in achievements)
      next(null, results)

# Removes the achievements that have already been earned from the list of achievements
filterEarned = (playerId, achievements, next) ->
  ids = _(achievements).pluck('id')
  redis.hmget "#{ACHIEVEMENT_KEY}:#{playerId}", ids, (err, flagged) ->
    return next(err)  if err
    filtered = achievements.filter((a, i) -> !flagged[i])
    next(null, filtered)

# Flags achievements that have been earned in redis so we don't bother the webservice with it
flagEarned = (playerId, achievements, next) ->
  hash = {}
  hash[a.id] = true  for a in achievements
  redis.hmset("#{ACHIEVEMENT_KEY}:#{playerId}", hash)

# Notifies the server about achievements to add to the user
# All achievements that have been successfully get passed to next
notifyServer = (playerId, achievements, next) ->
  if config.IS_LOCAL
    return next(null, achievements)

  request.post {
    url: "http://pokebattle.com/api/v1/achievements/"
    json: achievements.map((a) -> a.id)
  }, (err, res, duplicates) ->
    return next(err)  if err

    # Remove duplicate achievements then return
    filtered = achievements.filter((a) -> a.id not in duplicates)
    next(null, achievements)

@registerBattle = (server, battle) ->
  return  if battle.format != 'xy1000'
  return  unless Conditions.RATED_BATTLE in battle.conditions 

  battle.once 'ratingsUpdated', ->
    for player in battle.players
      checkAchievements player.ratingKey, (err, achievements) ->
        return if err
        
        filterEarned player.id, achievements, (err, achievements) ->
          return  if err
          return  if achievements.length == 0

          notifyServer player.id, achievements, (err, result) ->
            return  if err
            return  if achievements.length == 0

            flagEarned(player.id, achievements)

            # for each new achievement, notify the user if said user is online
            user = server.getUser(player.id)
            if user
              user.send('achievementsEarned', achievements)