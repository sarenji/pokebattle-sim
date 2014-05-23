require '../../helpers'

{BattleServer} = require('../../../server/server')
{User} = require('../../../server/user')
{Conditions} = require '../../../shared/conditions'
{Factory} = require '../../factory'
should = require('should')

generateTeam = ->
  [ Factory("Magikarp")
    Factory("Gyarados")
    Factory('Hitmonchan')
    Factory("Celebi")
    Factory("Blissey")
    Factory("Alakazam") ]

describe 'Validations: Prankster + Swagger', ->
  it "returns an error if the team has a Pokemon with Prankster + Swagger", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    team[0] = Factory("Sableye", ability: "Prankster", moves: [ "Swagger" ])
    conditions = [ Conditions.PRANKSTER_SWAGGER_CLAUSE ]

    server.validateTeam(team, format, conditions).should.not.be.empty

  it "returns no error if the team has no Prankster + Swagger Pokemon", ->
    server = new BattleServer()
    format = 'xy1000'
    conditions = [ Conditions.PRANKSTER_SWAGGER_CLAUSE ]

    server.validateTeam(generateTeam(), format, conditions).should.be.empty
