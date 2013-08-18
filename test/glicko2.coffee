glicko2 = require '../server/glicko2'

describe "Glicko2", ->
  beforeEach ->
    @__tau = glicko2.config.TAU
    glicko2.config.TAU = 0.5
    @p1 = {rating: 1500, deviation: 200, volatility: 0.06}
    @p2 = {rating: 1400, deviation:  30}
    @p3 = {rating: 1550, deviation: 100}
    @p4 = {rating: 1700, deviation: 300}
    @matches = [
      {opponent: @p2, score: 1}
      {opponent: @p3, score: 0}
      {opponent: @p4, score: 0}
    ]
    @opponents = @matches.map((m) -> m.opponent)
    @scores = @matches.map((m) -> m.score)

  afterEach ->
    glicko2.config.TAU = @__tau

  describe "#ratingFromGlicko", ->
    it "transforms ratings to Glicko2 from Glicko", ->
      glicko2.ratingFromGlicko(@p1.rating).should.equal(0)
      glicko2.ratingFromGlicko(@p2.rating).should.equal(-0.57746122636595565791)
      glicko2.ratingFromGlicko(@p3.rating).should.equal(0.2887306131829778)
      glicko2.ratingFromGlicko(@p4.rating).should.equal(1.1549224527319113)

  describe "#deviationFromGlicko", ->
    it "transforms deviations to Glicko2 from Glicko", ->
      glicko2.deviationFromGlicko(@p1.deviation).should.equal(1.1549224527319113)
      glicko2.deviationFromGlicko(@p2.deviation).should.equal(0.1732383679097867)
      glicko2.deviationFromGlicko(@p3.deviation).should.equal(0.5774612263659556)
      glicko2.deviationFromGlicko(@p4.deviation).should.equal(1.732383679097867)

  describe "#g", ->
    it "applies a function to a deviation", ->
      dfg = glicko2.deviationFromGlicko
      glicko2.g(dfg(@p2.deviation)).should.equal(0.9954697656070619)
      glicko2.g(dfg(@p3.deviation)).should.equal(0.9528736649355471)
      glicko2.g(dfg(@p4.deviation)).should.equal(0.7231504586157951)

  describe "#E", ->
    it "applies a function to a deviation", ->
      rfg = glicko2.ratingFromGlicko
      dfg = glicko2.deviationFromGlicko
      glicko2.E(rfg(@p1.rating), rfg(@p2.rating), dfg(@p2.deviation)).should.equal(0.6398804244872593)
      glicko2.E(rfg(@p1.rating), rfg(@p3.rating), dfg(@p3.deviation)).should.equal(0.431649645227976)
      glicko2.E(rfg(@p1.rating), rfg(@p4.rating), dfg(@p4.deviation)).should.equal(0.30255033173677587)

  describe "calculations", ->
    beforeEach ->
      rfg = glicko2.ratingFromGlicko
      dfg = glicko2.deviationFromGlicko
      @gPlayers = []
      @ePlayers = []

      for opponent in @opponents
        @gPlayers.push glicko2.g(dfg(opponent.deviation))
        @ePlayers.push glicko2.E(rfg(@p1.rating), rfg(opponent.rating), dfg(opponent.deviation))

    describe "#calculateEstimatedVariance", ->
      it "estimates variance based on the g and E factors of opponents", ->
        estimatedVariance = glicko2.calculateEstimatedVariance(@gPlayers, @ePlayers)
        estimatedVariance.should.equal(1.7811042373512078)

    describe "#calculateImprovementSum", ->
      it "sums up improvements", ->
        improvementSum = glicko2.calculateImprovementSum(@gPlayers, @ePlayers, @scores)
        improvementSum.should.equal(-0.27160884114013806)

    describe "#calculateNewVolatility", ->
      it "creates a new volatility", ->
        estimatedVariance = glicko2.calculateEstimatedVariance(@gPlayers, @ePlayers)
        improvementSum = glicko2.calculateImprovementSum(@gPlayers, @ePlayers, @scores)
        glicko2.calculateNewVolatility(improvementSum,
          glicko2.deviationFromGlicko(@p1.deviation),
          estimatedVariance,
          @p1.volatility,
          glicko2.config.TAU).should.equal(0.059995996477963935)

  describe "#calculate", ->
    it "combines all the previous steps together correctly", ->
      {rating, deviation, volatility} = glicko2.calculate(@p1, @matches)
      rating.should.equal(1464.0719365246412)
      deviation.should.equal(151.3503881127135)
      volatility.should.equal(0.059995996477963935)
