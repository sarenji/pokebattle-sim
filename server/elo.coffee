elo = require('elo-rank')()

createPlayer = ->
  {rating: 1000}

calculate = (player, matches, options = {}) ->
  playerRating = player.rating
  for {opponent, score} in matches
    expected = elo.getExpected(playerRating, opponent.rating)
    playerRating = elo.updateRating(expected, score, playerRating)
  {rating: playerRating}

module.exports = {createPlayer, calculate}
