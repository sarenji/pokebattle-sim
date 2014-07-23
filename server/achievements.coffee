# Handles giving achievements to players
# Due to time constraints, this was rushed and not very generalized. This module can be expanded
# on in the future.

{_} = require 'underscore'
ratings = require './ratings'
{Conditions} = require '../shared/conditions'

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
    id: 1,
    name: "Taste of Victory"
    condition: "Win on PokeBattle for the first time"
    conditionFn: winCount(1)
  },
  {
    id: 1,
    name: "Centurian"
    condition: "Win 100 times"
    conditionFn: winCount(100)
  },
  {
    id: 1,
    name: "Jackpot!"
    condition: "Lucky 777 victories"
    conditionFn: winCount(777)
  },
  {
    id: 1,
    name: "Ladder Monster"
    condition: "Win a beastly 2500 matches"
    conditionFn: winCount(2500)
  },
  {
    id: 1,
    name: "Mile High Club"
    condition: "Win 52"
    conditionFn: winCount(5280)
  },
  {
    id: 1,
    name: "Better than Phil"
    condition: "More than 7086 victories"
    conditionFn: winCount(7087)
  },
  {
    id: 1,
    name: "KAKAROT!"
    condition: "What? More than 9000 victories?!"
    conditionFn: winCount(9001)
  },

  # ladder ranking achievements go here

  {
    id: 1,
    name: "On a Roll!"
    condition: "Five in a row"
    conditionFn: streak(5)
  },
  {
    id: 1,
    name: "Perfect Ten!"
    condition: "10 in a row, very nice"
    conditionFn: streak(10)
  },
  {
    id: 1,
    name: "Incredible!"
    condition: "15 victories!"
    conditionFn: streak(15)
  },
  {
    id: 1,
    name: "Unreal!"
    condition: "20 victories in a row"
    conditionFn: streak(20)
  },
  {
    id: 1,
    name: "Impossible!"
    condition: "30 victories! Hopefully counting"
    conditionFn: streak(30)
  },
  {
    id: 1,
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

      # Remove the conditionFn attribute, since the client won't see it
      results = for achievement in achievements
        achievement = _(achievement).clone()
        delete achievement.conditionFn  
        achievement

      next(null, results)

# Removes the achievements that have already been earned from the list of achievements
filterEarned = (playerId, achievements, next) ->
  # TODO: implement this
  next(null, achievements)

@registerBattle = (server, battle) ->
  return  if battle.format != 'xy1000'
  return  unless Conditions.RATED_BATTLE in battle.conditions 

  battle.once 'ratingsUpdated', ->
    for player in battle.players
      checkAchievements player.ratingKey, (err, achievements) ->
        console.log achievements
        filterEarned player.id, achievements, (err, achievements) ->
          return  if err
          return  if achievements.length == 0

          # for each new achievement, notify the user if said user is online
          user = server.getUser(player.id)
          if user
            user.send('achievementsEarned', achievements)