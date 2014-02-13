require '../../helpers'

shared = require '../../shared'
{Conditions} = require '../../../shared/conditions'
{Protocol} = require '../../../shared/protocol'
{Factory} = require '../../factory'

describe "Team preview", ->
  it "starts the battle by passing team info and requesting team order", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = [ Factory("Magikarp") ]
    team2 = [ Factory("Magikarp") ]
    shared.build(this, {conditions, team1, team2})
    mock = @sandbox.mock(@battle).expects('startBattle').never()
    spy = @sandbox.spy(@battle, 'tell')
    @controller.beginBattle()
    mock.verify()
    spy.calledWith(Protocol.TEAM_PREVIEW).should.be.true

  it "waits until all players have arranged their teams before starting", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = [ Factory("Magikarp") ]
    team2 = [ Factory("Magikarp") ]
    shared.build(this, {conditions, team1, team2})
    mock = @sandbox.mock(@battle).expects('startBattle').never()
    @controller.beginBattle()
    @controller.arrangeTeam(@id1, [ 0 ])
    mock.verify()
    @battle.startBattle.restore()

    mock = @sandbox.mock(@battle).expects('startBattle').once()
    @controller.arrangeTeam(@id2, [ 0 ])
    mock.verify()

  it "rejects team arrangements that aren't arrays", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = [ Factory("Magikarp") ]
    team2 = [ Factory("Magikarp") ]
    shared.create.call(this, {conditions, team1, team2})
    arrangement = true
    @controller.arrangeTeam(@id1, arrangement).should.be.false

  it "accepts arrays of integers (arrangements) matching team length", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = [ Factory("Magikarp") ]
    team2 = [ Factory("Magikarp") ]
    shared.create.call(this, {conditions, team1, team2})
    arrangement = [ 0 ]
    @controller.arrangeTeam(@id1, arrangement).should.be.true

  it "rejects team arrangements that are smaller than the team length", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = [ Factory("Magikarp") ]
    team2 = [ Factory("Magikarp") ]
    shared.create.call(this, {conditions, team1, team2})
    arrangement = []
    @controller.arrangeTeam(@id1, arrangement).should.be.false

  it "rejects team arrangements that are larger than the team length", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = [ Factory("Magikarp") ]
    team2 = [ Factory("Magikarp") ]
    shared.create.call(this, {conditions, team1, team2})
    arrangement = [ 0, 1 ]
    @controller.arrangeTeam(@id1, arrangement).should.be.false

  it "rejects team arrangements containing negative indices", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = [ Factory("Magikarp") ]
    team2 = [ Factory("Magikarp") ]
    shared.create.call(this, {conditions, team1, team2})
    arrangement = [ -1 ]
    @controller.arrangeTeam(@id1, arrangement).should.be.false

  it "rejects team arrangements containing indices out of bounds", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = [ Factory("Magikarp") ]
    team2 = [ Factory("Magikarp") ]
    shared.create.call(this, {conditions, team1, team2})
    arrangement = [ 1 ]
    @controller.arrangeTeam(@id1, arrangement).should.be.false

  it "rejects team arrangements containing non-unique indices", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = (Factory("Magikarp")  for x in [0..1])
    shared.create.call(this, {conditions, team1})
    arrangement = [ 1, 1 ]
    @controller.arrangeTeam(@id1, arrangement).should.be.false

  it "rejects team arrangements that have some non-numbers", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = (Factory("Magikarp")  for x in [0..1])
    shared.create.call(this, {conditions, team1})
    arrangement = [ 1, "a" ]
    @controller.arrangeTeam(@id1, arrangement).should.be.false

  it "rejects team arrangements that don't point to a correct index", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = (Factory("Magikarp")  for x in [0..1])
    shared.create.call(this, {conditions, team1})
    arrangement = [ 1, .5 ]
    @controller.arrangeTeam(@id1, arrangement).should.be.false

  it "rejects team arrangements if the battle has already begun", ->
    team1 = (Factory("Magikarp")  for x in [0..1])
    shared.create.call(this, {team1})
    arrangement = [ 1, 0 ]
    @controller.arrangeTeam(@id1, arrangement).should.be.false

  it "rearranges team when given a valid array of indices", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = [ Factory("Magikarp"), Factory("Gyarados"), Factory("Celebi") ]
    team2 = [ Factory("Magikarp"), Factory("Gyarados"), Factory("Celebi") ]
    shared.create.call(this, {conditions, team1, team2})
    @controller.arrangeTeam(@id1, [ 0, 2, 1 ])
    @controller.arrangeTeam(@id2, [ 2, 0, 1 ])
    @team1.at(0).name.should.equal("Magikarp")
    @team1.at(1).name.should.equal("Celebi")
    @team1.at(2).name.should.equal("Gyarados")
    @team2.at(0).name.should.equal("Celebi")
    @team2.at(1).name.should.equal("Magikarp")
    @team2.at(2).name.should.equal("Gyarados")

  it "rejects team arrangement when arranging is over", ->
    conditions = [ Conditions.TEAM_PREVIEW ]
    team1 = [ Factory("Magikarp"), Factory("Gyarados"), Factory("Celebi") ]
    team2 = [ Factory("Magikarp"), Factory("Gyarados"), Factory("Celebi") ]
    shared.create.call(this, {conditions, team1, team2})
    @controller.arrangeTeam(@id1, [ 0, 2, 1 ])
    @controller.arrangeTeam(@id2, [ 2, 0, 1 ])
    @controller.arrangeTeam(@id2, [ 2, 0, 1 ]).should.be.false
