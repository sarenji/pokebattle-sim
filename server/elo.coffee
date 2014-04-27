elo = require('elo-rank')

createPlayer = ->
  {rating: 1000}

calculate = (player, matches, options = {}) ->
  playerRating = player.rating
  for {opponent, rating, score} in matches
    expected = elo.getExpected(playerRating, rating)
    playerRating = elo.updateRating(expected, score, playerRating)
  playerRating

module.exports = {createPlayer, calculate}
