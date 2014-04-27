{_} = require('underscore')

class WHR
  constructor: (config = {}) ->
    @config = _.clone(config)
    @config.w2 ?= 300.0  # elo^2
    @games = []
    @players = {}

  printOrderedRatings: ->
    players = _.values(@players.values).filter((p) -> p.days.count > 0)
    players.sort (a, b) ->
      a.days[a.days.length - 1].gamma()
    for p, idx in players when p.days.count > 0
      console.log "#{p.name} => #{p.days.map((p) -> p.elo())}"

  logLikelihood: ->
    score = 0.0
    for p in _.values(@players)
      score += p.logLikelihood()  unless p.days.length == 0
    score

  playerByName: (name) ->
    @players[name] ||= new Player(name, @config)

  ratingsForPlayer: (name) ->
    player = @playerByName(name)
    player.days.map (d, i) ->
      [d.day, Math.round(d.elo()), Math.round(d.uncertainty * 100)]

  setupGame: (black, white, winner, time_step, handicap, extras = {}) ->
    # Avoid self-played games (no info)
    if black == white
      throw new Error("Invalid game (black player == white player)")
      return

    whitePlayer = @playerByName(white)
    blackPlayer = @playerByName(black)
    new Game(blackPlayer, whitePlayer, winner, time_step, handicap, extras)

  createGame: (black, white, winner, time_step, handicap, extras = {}) ->
    game = @setupGame(black, white, winner, time_step, handicap, extras)
    @addGame(game)

  addGame: (game) ->
    game.whitePlayer.addGame(game)
    game.blackPlayer.addGame(game)
    if !game.bpd
      throw new Error("Bad game: #{game.toString()}")
    @games.push(game)
    game

  iterate: (count) ->
    @runOneIteration()  for x in [0...count]
    for name, player of @players
      player.updateUncertainty()
    count

  runOneIteration: ->
    for name, player of @players
      player.runOneNewtonIteration()

class Game
  constructor: (black, white, winner, timeStep, handicap, extras) ->
    @whitePlayer = white
    @blackPlayer = black
    @winner = winner
    @day = timeStep
    @handicap = handicap ? 0
    @extras = extras

  opponentsAdjustedGamma: (player) ->
    if player == @whitePlayer
      opponentElo = @bpd.elo() + @handicap
    else if player == @blackPlayer
      opponentElo = @wpd.elo() - @handicap
    else
      throw new Error("No opponent for #{player}, since they're not in this game: #{@toString()}.")

    rval = 10 ** (opponentElo / 400.0)
    if rval == 0 || rval == Infinity || isNaN(rval)
      throw new UnstableRatingError("bad adjusted gamma: #{@toString()}")
    rval

  predictionScore: ->
    p = @whiteWinProbability()
    if p == 0.5
      0.5
    else if (winner == "W" && p > 0.5) || (winner == "B" && p < 0.5)
      1.0
    else
      0.0

  toString: ->
    "[WHR: W:#{@whitePlayer.name}(r=#{@wpd?.r ? '?'}) B:#{@blackPlayer.name}(r=#{@bpd?.r ? '?'}) winner = #{@winner}, handicap = #{@handicap}]"

  # This is the Bradley-Terry Model
  whiteWinProbability: ->
    gamma = @wpd.gamma()
    gamma / (gamma + @opponentsAdjustedGamma(@whitePlayer))

  blackWinProbability: ->
    gamma = @bpd.gamma()
    gamma / (gamma + @opponentsAdjustedGamma(@blackPlayer))

class Player
  constructor: (name, config) ->
    @name = name
    # Convert from elo^2 to r^2
    @w2 = (Math.sqrt(config.w2) * Math.log(10) / 400) ** 2
    @days = []

  toString: ->
    "Player:(#{@name})"

  logLikelihood: ->
    sum = 0.0
    sigma2 = @computeSigma2()
    n = days.length
    for i in [0...n]
      prior = 0
      if i < n - 1
        rd = @days[i].r - @days[i+1].r
        temp = (1 / Math.sqrt(2 * Math.PI * sigma2[i]))
        temp *= Math.exp(-(rd ** 2) / 2 * sigma2[i])
        prior += temp
      if i > 0
        rd = days[i].r - days[i-1].r
        temp = (1 / Math.sqrt(2 * Math.PI * sigma2[i - 1]))
        temp *= Math.exp(-(rd ** 2) / 2 * sigma2[i - 1])
        prior += temp
      if prior == 0
        sum += @days[i].logLikelihood()
      else
        sum += @days[i].logLikelihood() + Math.log(prior)
    sum

  hessian: (days, sigma2) ->
    n = days.length
    matrix = []
    for row in [0...n]
      matrix.push([])
      for col in [0...n]
        value = switch
          when row == col
            prior = 0
            prior += -1.0 / sigma2[row]    if row < n - 1
            prior += -1.0 / sigma2[row-1]  if row > 0
            days[row].logLikelihoodSecondDerivative() + prior - 0.001
          when row == col - 1
            1.0 / sigma2[row]
          when row == col + 1
            1.0 / sigma2[col]
          else
            0
        matrix[row][col] = value
    matrix

  gradient: (r, days, sigma2) ->
    g = []
    n = days.length
    for day, idx in days
      prior = 0
      prior += -(r[idx] - r[idx+1]) / sigma2[idx]    if idx < n - 1
      prior += -(r[idx] - r[idx-1]) / sigma2[idx-1]  if idx > 0
      # if @debug
      #   puts "g[#{idx}] = #{day.logLikelihoodDerivative()} + #{prior}"
      # end
      g.push(day.logLikelihoodDerivative() + prior)
    g

  runOneNewtonIteration: ->
    for day in @days
      day.clearGameTermsCache()

    if @days.length == 1
      @days[0].updateBy1dNewtonsMethod()
    else if @days.length > 1
      @updateByNdimNewton()

  computeSigma2: ->
    sigma2 = []
    for d1, idx in @days[0...@days.length - 1]
      d2 = @days[idx + 1]
      sigma2.push(Math.abs(d2.day - d1.day) * @w2)
    sigma2

  updateByNdimNewton: ->
    r = @days.map((day) -> day.r)

    # sigma squared (used in the prior)
    sigma2 = @computeSigma2()

    h = @hessian(@days, sigma2)
    g = @gradient(r, @days, sigma2)

    a = []
    d = [h[0][0]]
    b = [h[0][1]]

    n = r.length
    for i in [1...n]
      a[i] = h[i][i - 1] / d[i - 1]
      d[i] = h[i][i] - a[i] * b[i - 1]
      b[i] = h[i][i + 1]

    y = [g[0]]
    for i in [1...n]
      y[i] = g[i] - a[i] * y[i - 1]

    x = []
    x[n - 1] = y[n - 1] / d[n - 1]
    for i in [(n - 2)..0] by -1
      x[i] = (y[i] - b[i] * x[i + 1]) / d[i]

    newR = _.zip(r, x).map(([ri, xi]) -> ri - xi)

    for r in newR when r > 650
      throw new UnstableRatingException("Unstable r (#{newR}) on player #{@toString()}")

    for day, idx in @days
      day.r = day.r - x[idx]

  covariance: ->
    r = @days.map((day) -> day.r)

    sigma2 = @computeSigma2()
    h = @hessian(@days, sigma2)
    g = @gradient(r, @days, sigma2)

    n = @days.length

    a = []
    d = [h[0][0]]
    b = [h[0][1]]

    n = r.length
    for i in [1...n]
      a[i] = h[i][i - 1] / d[i - 1]
      d[i] = h[i][i] - a[i] * b[i - 1]
      b[i] = h[i][i + 1]

    dp = []
    dp[n - 1] = h[n - 1][n - 1]
    bp = []
    bp[n - 1] = h[n - 1][n - 2]
    ap = []
    for i in [(n - 2)..0] by -1
      ap[i] = h[i][i + 1] / dp[i + 1]
      dp[i] = h[i][i] - ap[i] * bp[i + 1]
      bp[i] = h[i][i - 1]

    v = []
    for i in [0...(n - 1)]
      v[i] = dp[i + 1] / (b[i] * bp[i + 1] - d[i] * dp[i + 1])
    v[n - 1] = -1 / d[n - 1]

    matrix = []
    for row in [0...n]
      matrix.push([])
      for col in [0...n]
        value = switch
          when row == col
            v[row]
          when row == col - 1
            -1 * a[col] * v[col]
          else
            0
        matrix[row][col] = value
    matrix

  updateUncertainty: ->
    if @days.length > 0
      c = @covariance()
      u = [0...@days.length].map((i) -> c[i][i]) # u = variance
      for day, i in @days
        day.uncertainty = u[i]

  addGame: (game) ->
    lastDay = @days[@days.length - 1]
    if !lastDay? || lastDay.day != game.day
      newPlayerDay = new PlayerDay(this, game.day)
      if @days.length == 0
        newPlayerDay.isFirstDay = true
        newPlayerDay.gamma(1)
      else
        newPlayerDay.gamma(lastDay.gamma())
      @days.push(newPlayerDay)
      lastDay = newPlayerDay
    if game.whitePlayer == this
      game.wpd = lastDay
    else
      game.bpd = lastDay
    lastDay.addGame(game)

class PlayerDay
  constructor: (@player, @day) ->
    @isFirstDay = false
    @wonGames = []
    @lostGames = []

  gamma: (gamma) ->
    @r = Math.log(gamma)  if gamma?
    Math.exp(@r)

  elo: (elo) ->
    @r = elo * (Math.log(10) / 400.0)  if elo?
    @r * 400.0 / Math.log(10)

  clearGameTermsCache: ->
    delete @_wonGameTerms
    delete @_lostGameTerms

  wonGameTerms: ->
    if !@_wonGameTerms?
      @_wonGameTerms = @wonGames.map (g) =>
        otherGamma = g.opponentsAdjustedGamma(@player)
        [1.0, 0.0, 1.0, otherGamma]
      if @isFirstDay
        # win against virtual player ranked with gamma = 1.0
        @_wonGameTerms.push([1.0, 0.0, 1.0, 1.0])
    @_wonGameTerms

  lostGameTerms: ->
    if !@_lostGameTerms?
      @_lostGameTerms = @lostGames.map (g) =>
        otherGamma = g.opponentsAdjustedGamma(@player)
        [0.0, otherGamma, 1.0, otherGamma]
      if @isFirstDay
        # loss against virtual player ranked with gamma = 1.0
        @_lostGameTerms.push([0.0, 1.0, 1.0, 1.0])
    @_lostGameTerms

  logLikelihoodSecondDerivative: ->
    sum = 0.0
    gamma = @gamma()
    terms = [].concat(@wonGameTerms(), @lostGameTerms())
    for [a, b, c, d] in terms
      sum += (c * d) / ((c * gamma + d) ** 2.0)
    -1 * gamma * sum

  logLikelihoodDerivative: ->
    tally = 0.0
    gamma = @gamma()
    wonTerms = @wonGameTerms()
    terms = [].concat(wonTerms, @lostGameTerms())
    for [a, b, c, d] in terms
      tally += c / (c * gamma + d)
    wonTerms.length - gamma * tally

  logLikelihood: ->
    tally = 0.0
    gamma = @gamma()
    for [a, b, c, d] in @wonGameTerms()
      tally += Math.log(a * gamma)
      tally -= Math.log(c * gamma + d)
    for [a, b, c, d] in @lostGameTerms()
      tally += Math.log(b)
      tally -= Math.log(c * gamma + d)
    tally

  addGame: (game) ->
    if (game.winner == "W" && game.whitePlayer == @player) ||
       (game.winner == "B" && game.blackPlayer == @player)
      @wonGames.push(game)
    else
      @lostGames.push(game)

  updateBy1dNewtonsMethod: ->
    @r -= (@logLikelihoodDerivative() / @logLikelihoodSecondDerivative())

class UnstableRatingError extends Error

module.exports = {WHR, Game, Player, PlayerDay, UnstableRatingError}
