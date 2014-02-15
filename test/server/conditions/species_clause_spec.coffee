require '../../helpers'

{BattleServer} = require('../../../server/server')
gen = require('../../../server/generations')
{User} = require('../../../server/user')
{Conditions} = require '../../../shared/conditions'
{Factory} = require '../../factory'
should = require('should')

describe 'Validations: Species Clause', ->
  it "returns an error if the team has more than one of the same species", ->
    server = new BattleServer()
    generation = 'xy'
    team = [ Factory("Rotom", forme: "wash"), Factory("Rotom", forme: "heat") ]
    conditions = [ Conditions.SPECIES_CLAUSE ]

    server.validateTeam(team, generation, conditions).should.not.be.empty

  it "returns no error if the team shares no species", ->
    server = new BattleServer()
    generation = 'xy'
    team = [
      Factory("Magikarp", moves: [ "Splash" ])
      Factory("Gyarados", moves: [ "Dragon Dance" ])
    ]
    conditions = [ Conditions.SPECIES_CLAUSE ]

    server.validateTeam(team, generation, conditions).should.be.empty
