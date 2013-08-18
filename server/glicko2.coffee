# Formula from Glickman's paper:
# http://glicko.net/glicko/glicko2.pdf

config =
  TAU:                   0.5
  DEFAULT_RATING:        1500
  DEFAULT_DEVIATION:     350
  DEFAULT_VOLATILITY:    0.06
  CONVERGENCE_TOLERANCE: 0.000001

GLICKO_CONSTANT = 173.1718
PI_SQUARED = Math.PI * Math.PI

ratingFromGlicko = (rating) ->
  (rating - 1500) / GLICKO_CONSTANT

deviationFromGlicko = (deviation) ->
  deviation / GLICKO_CONSTANT

g = (deviation) ->
  1 / Math.sqrt(1 + 3 * deviation * deviation / PI_SQUARED)

E = (mu, opponentMu, opponentPhi) ->
  1 / (1 + Math.exp(-g(opponentPhi) * (mu - opponentMu)))

_extractPlayer = (player) ->
  {rating, deviation, volatility} = player

createPlayer = ->
  rating: DEFAULT_RATING
  deviation: DEFAULT_DEVIATION
  volatility: DEFAULT_VOLATILITY

calculate = (player, matches, options = {}) ->
  # Step 1: Initialize tau. Players with no rating are assumed to have been
  # handled already using the createPlayer function.
  tau = options.systemConstant || config.TAU
  extractPlayer    = (options.extractPlayer || _extractPlayer)
  glickoPlayer     = extractPlayer(player)
  playerRating     = ratingFromGlicko(glickoPlayer.rating)
  playerDeviation  = deviationFromGlicko(glickoPlayer.deviation)
  playerVolatility = glickoPlayer.volatility

  # Step 2: Convert from Glicko to Glicko2
  gPlayers = []
  ePlayers = []
  scores   = []
  for match in matches
    {opponent, score} = match
    glickoOpponent = extractPlayer(opponent)
    opponentRating = ratingFromGlicko(opponent.rating)
    opponentDeviation = deviationFromGlicko(opponent.deviation)
    gPlayers.push g(opponentDeviation)
    ePlayers.push E(playerRating, opponentRating, opponentDeviation)
    scores.push   score

  # Step 3: Compute estimated variance (v)
  estimatedVariance = calculateEstimatedVariance(gPlayers, ePlayers)

  # Step 4: Compute estimated improvement in rating (delta)
  improvementSum = calculateImprovementSum(gPlayers, ePlayers, scores)

  # Step 5: Determine new volatility (delta prime)
  newVolatility = calculateNewVolatility(improvementSum, playerDeviation,
    estimatedVariance, playerVolatility, tau)

  # Step 6: Update rating deviation to new pre-rating period value
  periodValue = playerDeviation * playerDeviation + newVolatility * newVolatility

  # Step 7: Determine new rating and rating deviation
  newDeviation = 1 / Math.sqrt(1 / periodValue + 1 / estimatedVariance)
  newRating = playerRating + newDeviation * newDeviation * improvementSum

  # Step 8: Convert back to Glicko scale
  rating     = GLICKO_CONSTANT * newRating + config.DEFAULT_RATING
  deviation  = GLICKO_CONSTANT * newDeviation
  volatility = newVolatility

  # Return results
  return {rating, deviation, volatility}

calculateImprovementSum = (gPlayers, ePlayers, scores) ->
  improvementSum = 0.0
  for gPlayer, i in gPlayers
    improvementSum += gPlayer * (scores[i] - ePlayers[i])
  improvementSum

calculateEstimatedVariance = (gPlayers, ePlayers) ->
  estimatedVariance = 0.0
  for gPlayer, i in gPlayers
    gSquared = gPlayer * gPlayer
    ePlayer  = ePlayers[i]
    estimatedVariance += gSquared * ePlayer * (1.0 - ePlayer)
  estimatedVariance = 1.0 / estimatedVariance
  estimatedVariance

calculateNewVolatility = (improvementSum, deviation, variance, volatility, tau) ->
  # Step 5.1
  A = a = Math.log(volatility * volatility)
  improvement          = variance * improvementSum
  deviationSquared     = deviation * deviation
  varianceSquared      = variance * variance
  improvementSquared   = improvement * improvement
  tauSquared           = tau * tau
  convergenceTolerance = config.CONVERGENCE_TOLERANCE
  fIter = (x) -> f(deviationSquared, improvementSquared, tauSquared, variance, a, x)

  # Step 5.2
  if improvementSquared > varianceSquared + variance
    B = Math.log(improvementSquared - varianceSquared - variance)
  else
    absTau = Math.abs(tau)
    k  = 1
    k += 1  while fIter(a - k * absTau) < 0
    B = a - k * absTau

  # Step 5.3
  fA = fIter(A)
  fB = fIter(B)
  while Math.abs(B - A) > convergenceTolerance
    # Step 5.4a
    C  = A + (A - B) * fA / (fB - fA)
    fC = fIter(C)
    # Step 5.4b
    if fC * fB < 0 then [A, fA] = [B, fB] else fA /= 2
    # Step 5.4c
    [B, fB] = [C, fC]

  # Step 5.5
  return Math.exp(A / 2)

f = (deviationSquared, improvementSquared, tauSquared, variance, a, x) ->
  expX        = Math.exp(x)
  denominator = deviationSquared + variance + expX
  ((expX * (improvementSquared - denominator) /
    (2 * denominator * denominator)) - ((x - a) / tauSquared))

getRatingEstimate = (rating, deviation) ->
  return 0  if deviation > 100
  rds = deviation * deviation
  sqr = sqrt(15.905694331435 * (rds + 221781.21786254))
  inner = (1500.0 - rating) * Math.PI / sqr
  return Math.floor(10000.0 / (1.0 + Math.pow(10.0, inner)) + 0.5) / 100.0

module.exports = {
  calculate
  calculateImprovementSum
  calculateNewVolatility
  calculateEstimatedVariance
  createPlayer
  ratingFromGlicko
  deviationFromGlicko
  getRatingEstimate
  config
  g
  E
}
