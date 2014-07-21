# Handles giving achievements to players
# Due to time constraints, this was rushed and not very generalized. This module can be expanded
# on in the future.

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
    condition: winCount(1)
  },
  {
    id: 1,
    name: "Centurian"
    condition: winCount(100)
  },
  {
    id: 1,
    name: "Jackpot!"
    condition: winCount(777)
  },
  {
    id: 1,
    name: "Ladder Monster"
    condition: winCount(2500)
  },
  {
    id: 1,
    name: "Mile High Club"
    condition: winCount(5280)
  },
  {
    id: 1,
    name: "Better than Phil"
    condition: winCount(7087)
  },
  {
    id: 1,
    name: "KAKAROT!"
    condition: winCount(9001)
  },

  # ladder ranking achievements go here

  {
    id: 1,
    name: "On a Roll!"
    condition: streak(5)
  },
  {
    id: 1,
    name: "Perfect Ten!"
    condition: streak(10)
  },
  {
    id: 1,
    name: "Incredible!"
    condition: streak(15)
  },
  {
    id: 1,
    name: "Unreal!"
    condition: streak(20)
  },
  {
    id: 1,
    name: "Impossible!"
    condition: streak(30)
  },
  {
    id: 1,
    name: "The One"
    condition: streak(50)
  }
]

# Returns the achievements a player is eligible for, including already earned ones
# id is the rating key used to identify the player
checkAchievements = (id, next) ->
  ratings.getRatio id, (err, ratio) ->
    ratings.getStreak id, (err, streak) ->
      # Return what achievements the player is eligible for
      achievements = ACHIEVEMENTS.filter((o) -> o.condition(ratio, streak))
      next(null, achievements)

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
        filterAlreadyEarned player.id, achievements, (err, achievements) ->
          return  if err
          return  if achievements.length == 0

          # for each new achievement, notify the user if said user is online
          user = server.getUser(player.id)
          if user
            user.send('achievementEarned', JSON.stringify(achievements))