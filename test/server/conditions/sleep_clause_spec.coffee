require '../../helpers'

shared = require '../../shared'
{Conditions} = require '../../../shared/conditions'
{Attachment, Status} = require '../../../server/bw/attachment'
{Protocol} = require '../../../shared/protocol'
{Factory} = require '../../factory'

describe "Sleep Clause", ->
  it "prevents Sleep if the opponent was already slept by this team", ->
    conditions = [ Conditions.SLEEP_CLAUSE ]
    team1 = [ Factory("Magikarp"), Factory("Magikarp") ]
    team2 = [ Factory("Magikarp"), Factory("Magikarp") ]
    shared.create.call(this, {conditions, team1, team2})
    
    spore = @battle.getMove("Spore")
    @battle.performMove(@p1, spore)
    @battle.performSwitch(@p2, 1)

    mock = @sandbox.mock(spore).expects('fail').once()
    @battle.performMove(@p1, spore)
    mock.verify()

    @team2.at(0).has(Status.Sleep).should.be.false
    @team2.at(1).has(Status.Sleep).should.be.true

  it "doesn't prevent other statuses", ->
    conditions = [ Conditions.SLEEP_CLAUSE ]
    team1 = [ Factory("Magikarp"), Factory("Magikarp") ]
    team2 = [ Factory("Magikarp"), Factory("Magikarp") ]
    shared.create.call(this, {conditions, team1, team2})
    
    thunderWave = @battle.getMove("Thunder Wave")
    @battle.performMove(@p1, thunderWave)
    @battle.performSwitch(@p2, 1)

    mock = @sandbox.mock(thunderWave).expects('fail').never()
    @battle.performMove(@p1, thunderWave)
    mock.verify()

    @team2.at(0).has(Status.Paralyze).should.be.true
    @team2.at(1).has(Status.Paralyze).should.be.true

  it "doesn't prevent Sleep if the opponent was slept, but not by this team", ->
    conditions = [ Conditions.SLEEP_CLAUSE ]
    team1 = [ Factory("Magikarp"), Factory("Magikarp") ]
    team2 = [ Factory("Magikarp"), Factory("Magikarp") ]
    shared.create.call(this, {conditions, team1, team2})
    
    @team2.at(1).attach(Status.Sleep)

    spore = @battle.getMove("Spore")
    mock = @sandbox.mock(spore).expects('fail').never()
    @battle.performMove(@p1, spore)
    mock.verify()

    @team2.at(0).has(Status.Sleep).should.be.true
    @team2.at(1).has(Status.Sleep).should.be.true
