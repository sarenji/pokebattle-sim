require '../../helpers'

{_} = require 'underscore'
shared = require '../../shared'
{Conditions} = require '../../../shared/conditions'
{Protocol} = require '../../../shared/protocol'

describe "Battle timer", ->
  describe "without team preview", ->
    beforeEach ->
      @clock.tick(10000)
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

    it "recalculates timer after increasing time remaining", ->
      @battle.beginTurn()
      delta = @battle.TIMER_PER_TURN_INCREASE
      spy = @sandbox.spy(@battle, 'tell')

      @clock.tick(@battle.DEFAULT_TIMER + delta / 2)
      spy.calledWith(Protocol.TIMER_WIN).should.be.false

      @clock.tick(delta / 2)
      spy.calledWith(Protocol.TIMER_WIN).should.be.true

    it "stops timer for players who have moved", ->
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

    it "recalculates the timer after a player chooses an action", ->
      delta = 4000
      # give player 2 more time
      @battle.playerTimes[@id2] += delta

      @battle.recordMove(@id1, @battle.getMove("Splash"))

      spy = @sandbox.spy(@battle, 'tell')
      @clock.tick(@battle.DEFAULT_TIMER)
      spy.calledWith(Protocol.TIMER_WIN).should.be.false

      @clock.tick(delta)
      spy.calledWith(Protocol.TIMER_WIN).should.be.true

    it "grants time if player selected a move before the battle continued", ->
      @clock.tick(2500)

      spy = @sandbox.spy(@battle, 'requestActions')
      @controller.makeMove(@id1, "Splash")

      # 5 seconds after the player moves, the battle progresses
      @clock.tick(5000)
      @controller.makeMove(@id2, "Splash")
      (@battle.DEFAULT_TIMER + @battle.TIMER_PER_TURN_INCREASE -
        @battle.timeRemainingFor(@id1)).should.equal(2500)

      # Turn has progressed. Make another move and check the time.
      @clock.tick(2500)
      @controller.makeMove(@id1, "Splash")
      @clock.tick(5000)
      @controller.makeMove(@id2, "Splash")
      (@battle.DEFAULT_TIMER + 2 * @battle.TIMER_PER_TURN_INCREASE -
        @battle.timeRemainingFor(@id1)).should.equal(5000)

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

    it "sends timer updates when battle enters a new turn", ->
      @battle.recordMove(@id1, @battle.getMove("Splash"))
      @battle.recordMove(@id2, @battle.getMove("Splash"))

      spy = @sandbox.spy(@battle, 'tell')
      @battle.continueTurn()
      spy.calledWith(Protocol.UPDATE_TIMERS).should.be.false
      @battle.beginTurn()
      spy.calledWith(Protocol.UPDATE_TIMERS).should.be.true

    it "gets cleared if the battle ends prematurely", ->
      @battle.endBattle()

      mock = @sandbox.mock(@battle).expects('timerWin').never()
      @clock.tick(@battle.DEFAULT_TIMER)
      mock.verify()

    it "has a cap every time a new turn begins", ->
      @battle.TIMER_CAP = @battle.DEFAULT_TIMER

      @clock.tick(@battle.TIMER_PER_TURN_INCREASE >> 1)
      @battle.beginTurn()

      @battle.timeRemainingFor(@id1).should.equal(@battle.TIMER_CAP)

    it "has a cap every time a player gains time after a new action request", ->
      @battle.TIMER_CAP = @battle.DEFAULT_TIMER
      @battle.recordMove(@id1, @battle.getMove("U-turn"))

      @clock.tick(@battle.TIMER_PER_TURN_INCREASE >> 1)
      @battle.continueTurn()

      @battle.timeRemainingFor(@id1).should.equal(@battle.TIMER_CAP)

    it "recalculates timer every time an action is requested", ->
      # Player 2 has more time.
      delta = 4000
      @battle.playerTimes[@id2] += delta
      @battle.recordMove(@id2, @battle.getMove("U-turn"))
      @battle.recordMove(@id1, @battle.getMove("Splash"))

      @battle.continueTurn()
      # Action requested due to U-turn

      spy = @sandbox.spy(@battle, 'tell')
      @clock.tick(@battle.DEFAULT_TIMER)
      spy.calledWith(Protocol.TIMER_WIN).should.be.false

      @clock.tick(delta)
      spy.calledWith(Protocol.TIMER_WIN).should.be.true

  describe "with team preview", ->
    beforeEach ->
      @clock.tick(10000)
      shared.create.call this,
        conditions: [ Conditions.TIMED_BATTLE, Conditions.TEAM_PREVIEW ]

    it "starts a timer that auto-starts the battle after 1.5 mins", ->
      @battle.arranging.should.be.true
      spy = @sandbox.spy(@battle, 'startBattle')
      @clock.tick(@battle.TEAM_PREVIEW_TIMER)
      spy.calledOnce.should.be.true
      @battle.arranging.should.be.false

    it "arranges teams of those who already submitted arrangements", ->
      @battle.arranging.should.be.true
      arrangement = [0...@team1.size()]
      arrangement.reverse()
      pokemon = _.clone(@team1.pokemon)
      pokemon.reverse()
      @controller.arrangeTeam(@id1, arrangement)
      @clock.tick(@battle.TEAM_PREVIEW_TIMER)
      @team1.pokemon.should.eql(pokemon)
