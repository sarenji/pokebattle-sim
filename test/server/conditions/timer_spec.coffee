require '../../helpers'

shared = require '../../shared'
{Conditions} = require '../../../shared/conditions'
{Protocol} = require '../../../shared/protocol'

describe "Battle timer", ->
  describe "without team preview", ->
    beforeEach ->
      shared.create.call this,
        conditions: [ Conditions.TIMED_BATTLE ]
      @battle.TIMER_CAP = Infinity

    it "starts a timer that ends the battle in 5 minutes", ->
      @battle.isOver().should.be.false
      delta = 100
      @clock.tick(@battle.DEFAULT_TIMER - delta)
      @battle.isOver().should.be.false
      @clock.tick(delta)
      @battle.isOver().should.be.true

    it "declares a timer win for the player that didn't run out of time", ->
      @battle.playerTimes[@id1] += 1000
      spy = @sandbox.spy(@battle, 'tell')
      @clock.tick(@battle.DEFAULT_TIMER)
      index1 = @battle.getPlayerIndex(@id1)
      spy.calledWith(Protocol.TIMER_WIN, index1).should.be.true

    it "increases time remaining by 20 seconds for each player each turn", ->
      @battle.timeRemainingFor(@id1).should.equal(@battle.DEFAULT_TIMER)

      @battle.beginTurn()
      delta = @battle.TIMER_PER_TURN_INCREASE
      @battle.timeRemainingFor(@id1).should.equal(@battle.DEFAULT_TIMER + delta)
      @battle.timeRemainingFor(@id2).should.equal(@battle.DEFAULT_TIMER + delta)

      @battle.beginTurn()
      delta *= 2
      @battle.timeRemainingFor(@id1).should.equal(@battle.DEFAULT_TIMER + delta)
      @battle.timeRemainingFor(@id2).should.equal(@battle.DEFAULT_TIMER + delta)

    it "stops the timer at the time of the player's last action", ->
      delta = 5000
      @battle.timeRemainingFor(@id1).should.equal(@battle.DEFAULT_TIMER)
      @battle.timeRemainingFor(@id2).should.equal(@battle.DEFAULT_TIMER)

      @clock.tick(delta)
      @battle.timeRemainingFor(@id1).should.equal(@battle.DEFAULT_TIMER - delta)
      @battle.timeRemainingFor(@id2).should.equal(@battle.DEFAULT_TIMER - delta)

      @battle.recordMove(@id1, @battle.getMove("Splash"))

      @clock.tick(delta)
      @battle.timeRemainingFor(@id1).should.equal(@battle.DEFAULT_TIMER - delta)
      @battle.timeRemainingFor(@id2).should.equal(@battle.DEFAULT_TIMER - 2 * delta)

    it "grants time if player selected a move before the battle continued", ->
      @clock.tick(2500)

      @controller.makeMove(@id1, "Splash")

      # 5 seconds after the player moves, the battle progresses
      @clock.tick(5000)
      @controller.makeMove(@id2, "Splash")
      @battle.timeRemainingFor(@id1).should
        .equal(@battle.DEFAULT_TIMER - 2500 + @battle.TIMER_PER_TURN_INCREASE)

      # Turn has progressed. Make another move and check the time.
      @clock.tick(2500)
      @controller.makeMove(@id1, "Splash")
      @clock.tick(5000)
      @battle.timeRemainingFor(@id1).should
        .equal(@battle.DEFAULT_TIMER - 5000 + @battle.TIMER_PER_TURN_INCREASE)

    it "ends battle if canceling after which they'd lose to timer", ->
      # So the second player won't trigger the end condition.
      @battle.playerTimes[@id2] += 4000

      @clock.tick(2500)

      @controller.makeMove(@id1, "Splash")
      @clock.tick(@battle.DEFAULT_TIMER)

      mock = @sandbox.mock(@battle).expects('timerWin').once()
      @controller.undoCompletedRequest(@id1)
      @battle.timeRemainingFor(@id1).should.equal(-2500)
      mock.verify()

    it "sends timer updates when battle continues", ->
      @battle.recordMove(@id1, @battle.getMove("Splash"))
      @battle.recordMove(@id2, @battle.getMove("Splash"))

      spy = @sandbox.spy(@battle, 'tell')
      @battle.continueTurn()
      spy.calledWith(Protocol.UPDATE_TIMERS).should.be.true

    it "gets cleared if the battle ends prematurely", ->
      @battle.endBattle()

      mock = @sandbox.mock(@battle).expects('timerWin').never()
      @clock.tick(@battle.DEFAULT_TIMER)
      mock.verify()

    it "does not cause an infinite loop on later turns", ->
      @battle.beginTurn()  for x in [1..5]
      spy = @sandbox.spy(@battle, 'startTimer')
      @clock.tick(@battle.DEFAULT_TIMER)
      @clock.tick(@battle.TIMER_PER_TURN_INCREASE)
      @clock.tick(@battle.TIMER_PER_TURN_INCREASE)
      spy.callCount.should.equal(1)
      spy.calledWith(Infinity).should.be.false

    it "has a cap every time a new turn begins", ->
      @battle.TIMER_CAP = @battle.DEFAULT_TIMER

      @clock.tick(@battle.TIMER_PER_TURN_INCREASE >> 1)
      @battle.beginTurn()

      @battle.timeRemainingFor(@id1).should.equal(@battle.TIMER_CAP)

    it "has a cap every time a player gains time after move selection", ->
      @battle.TIMER_CAP = @battle.DEFAULT_TIMER
      @battle.recordMove(@id1, @battle.getMove("Splash"))

      @clock.tick(@battle.TIMER_PER_TURN_INCREASE >> 1)
      @battle.continueTurn()

      @battle.timeRemainingFor(@id1).should.equal(@battle.TIMER_CAP)

  describe "with team preview", ->
    beforeEach ->
      shared.create.call this,
        conditions: [ Conditions.TIMED_BATTLE, Conditions.TEAM_PREVIEW ]

    it "starts a timer that automatically selects the team after 1 minute"
    it "does not automatically select the team those who already arranged"
