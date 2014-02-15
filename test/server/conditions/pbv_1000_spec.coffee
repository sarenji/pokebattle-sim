require '../../helpers'

{BattleServer} = require('../../../server/server')
gen = require('../../../server/generations')
{User} = require('../../../server/user')
{Conditions} = require '../../../shared/conditions'
{Factory} = require '../../factory'
should = require('should')

describe 'Validations: PBV 1000', ->
  it "returns an error if the team is over 1000 PBV", ->
    server = new BattleServer()
    user = new User("Batman")
    other = new User("Robin")
    challengeeId = other.id
    generation = 'xy'
    team = [ Factory("Arceus", moves: [ "Recover" ]) ]
    conditions = [ Conditions.PBV_1000 ]

    server.validateTeam(team, generation, conditions).should.not.be.empty

  it "returns no error if the team is under 1000 PBV", ->
    server = new BattleServer()
    user = new User("Batman")
    other = new User("Robin")
    challengeeId = other.id
    generation = 'xy'
    team = [ Factory("Magikarp", moves: [ "Splash" ]) ]
    conditions = [ Conditions.PBV_1000 ]

    server.validateTeam(team, generation, conditions).should.be.empty
