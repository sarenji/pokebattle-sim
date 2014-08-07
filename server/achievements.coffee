# Handles giving achievements to players
# Due to time constraints, this was rushed and not very generalized. This module can be expanded
# on in the future.

{_} = require 'underscore'
async = require 'async'
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
    condition: "Won on PokeBattle for the first time"
    medium_image: "1_TasteOfVictory_50x50.png"
    conditionFn: winCount(1)
  },
  {
    id: 2
    name: "Centurian"
    condition: "Won 100 times"
    medium_image: "100_Centurian_50x50.png"
    conditionFn: winCount(100)
  },
  {
    id: 3
    name: "Jackpot!"
    condition: "Lucky 777 victories"
    medium_image: "777_Jackpot_50x50.png"
    conditionFn: winCount(777)
  },
  {
    id: 4
    name: "Ladder Monster"
    condition: "Won a beastly 2500 matches"
    medium_image: "2500_LadderMonster_50x50_1.png"
    conditionFn: winCount(2500)
  },
  {
    id: 5
    name: "Mile High Club"
    condition: "Won 5280 ladder matches"
    medium_image: "5280_MileHighClub_50x50.png"
    conditionFn: winCount(5280)
  },
  {
    id: 6
    name: "Better than Phil"
    condition: "More than 7086 victories"
    medium_image: "7087_BetterThanPhil_50x50.png"
    conditionFn: winCount(7087)
  },
  {
    id: 7
    name: "KAKAROT!"
    condition: "What? More than 9000 victories?!"
    medium_image: "9001_KAKAROT_50x50.png"
    conditionFn: winCount(9001)
  },

  # ladder ranking achievements go here

  {
    id: 26
    name: "On a Roll!"
    condition: "Won 5 consecutive ladder matches"
    medium_image: "5_OnARoll_50x50.png"
    conditionFn: streak(5)
  },
  {
    id: 27
    name: "Perfect Ten!"
    condition: "Won 10 consecutive ladder matches"
    medium_image: "10_PerfectTen_50x50.png"
    conditionFn: streak(10)
  },
  {
    id: 28
    name: "Incredible!"
    condition: "Won 15 victories ladder matches"
    medium_image: "15_Incredible_50x50.png"
    conditionFn: streak(15)
  },
  {
    id: 29
    name: "Unreal!"
    condition: "Won 20 consecutive ladder matches"
    medium_image: "20_Unreal_50x50.png"
    conditionFn: streak(20)
  },
  {
    id: 30
    name: "Impossible!"
    condition: "Won 30 consecutive ladder matches"
    medium_image: "30_Impossible_50x50.png"
    conditionFn: streak(30)
  },
  {
    id: 31
    name: "The One"
    condition: "You've won 50 in a row! Amazing!"
    medium_image: "50_TheOne_50x50.png"
    conditionFn: streak(50)
  }
]

# Checks what achievements a player is eligible for
# The achievements are then awarded to the player
# Note: In the current implementation, playerId is actually a name
@checkAndAwardAchievements = (server, playerId, ratingKey, next = ->) ->
  checkAchievements ratingKey, (err, achievements) ->
    return next(err) if err
    return next() if achievements.length == 0

    filterEarned playerId, achievements, (err, achievements) ->
      return next(err) if err
      return next() if achievements.length == 0

      notifyServer playerId, achievements, (err, byStatus) ->
        return next(err) if err

        # TODO: Handle errors, probably add them to some queue to retry
        # Currently its fine, as playing another battle will do a re-evalation
        # but in the future this may not be the case!

        # Flag all of the achievements that have been earned
        achievementsToFlag = _.union(byStatus.success, byStatus.duplicate)
        flagEarned(playerId, achievementsToFlag)  if achievementsToFlag.length > 0

        # for each new achievement, notify the user if said user is online
        if byStatus.success.length > 0
          user = server.getUser(playerId)
          if user
            user.send('achievementsEarned', byStatus.success)

        next()

# Registers a battle with the achievement system
# If the battle is not eligible for achievements, it is ignored
@registerBattle = (server, battle) ->
  return  if battle.format != 'xy1000'
  return  unless Conditions.RATED_BATTLE in battle.conditions 

  battle.once 'ratingsUpdated', =>
    for player in battle.players
      @checkAndAwardAchievements(server, player.id, player.ratingKey)


# Returns the achievements a player is eligible for, including already earned ones
checkAchievements = (ratingKey, next) ->
  ratings.getRatio ratingKey, (err, ratio) ->
    ratings.getStreak ratingKey, (err, streak) ->
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
# All achievements are separated by server result and passed to next
# Note: In the current implementation, playerId is actually a name
# If playerId is refactored to a numerical id, the server will need to be updated
notifyServer = (playerId, achievements, next) ->
  achievementsByStatus =
    success: []
    duplicate: []
    error: []

  if config.IS_LOCAL
    achievementsByStatus.success = achievements
    return next(null, achievementsByStatus)

  calls = for achievement in achievements
    do (achievement) -> (callback) ->
      request.post {
        url: "https://www.pokebattle.com/api/v1/achievements/"
        json: { user: playerId, achievement: achievement.name }
      }, (err, res, data) ->
        status = "success"
        status = "error"  if err
        status = "duplicate" if data?.awarded
        achievementsByStatus[status].push(achievement)
        callback()

  async.parallel calls, (err, results) ->
    next(null, achievementsByStatus)
          