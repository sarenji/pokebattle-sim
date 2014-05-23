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

describe 'Validations: Species Clause', ->
  it "returns an error if the team has more than one of the same species", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    team[0] = Factory("Rotom", forme: "wash")
    team[1] = Factory("Rotom", forme: "heat")
    conditions = [ Conditions.SPECIES_CLAUSE ]

    server.validateTeam(team, format, conditions).should.not.be.empty

  it "returns no error if the team shares no species", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    conditions = [ Conditions.SPECIES_CLAUSE ]

    server.validateTeam(team, format, conditions).should.be.empty
