require '../../helpers'

{BattleServer} = require('../../../server/server')
gen = require('../../../server/generations')
{User} = require('../../../server/user')
{Conditions} = require '../../../shared/conditions'
{Factory} = require '../../factory'
should = require('should')

describe 'Validations: Prankster + Swagger', ->
  it "returns an error if the team has a Pokemon with Prankster + Swagger", ->
    server = new BattleServer()
    generation = 'xy'
    team = [ Factory("Sableye", ability: "Prankster", moves: [ "Swagger" ]) ]
    conditions = [ Conditions.PRANKSTER_SWAGGER_CLAUSE ]

    server.validateTeam(team, generation, conditions).should.not.be.empty

  it "returns no error if the team has no Prankster + Swagger Pokemon", ->
    server = new BattleServer()
    generation = 'xy'
    team = [ Factory("Magikarp") ]
    conditions = [ Conditions.PRANKSTER_SWAGGER_CLAUSE ]

    server.validateTeam(team, generation, conditions).should.be.empty
