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

describe 'Validations: Unreleased Ban', ->
  it "returns an error if a pokemon is unreleased", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    team[0] = Factory("Diancie", item: "Leftovers", moves: [ "Moonblast" ])
    conditions = [ Conditions.UNRELEASED_BAN ]

    server.validateTeam(team, format, conditions).should.not.be.empty

  it "returns an error if a pokemon has an unreleased item", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    team[0] = Factory("Latias", item: "Soul Dew", moves: [ "Psychic" ])
    conditions = [ Conditions.UNRELEASED_BAN ]

    server.validateTeam(team, format, conditions).should.not.be.empty

  it "returns an error if a pokemon has an unreleased ability", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    team[0] = Factory("Suicune", ability: "Water Absorb", moves: [ "Surf" ])
    conditions = [ Conditions.UNRELEASED_BAN ]

    server.validateTeam(team, format, conditions).should.not.be.empty

  it "returns no error if all pokemon have nothing unreleased", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    team[0] = Factory("Latias", item: "Leftovers", moves: [ "Psychic" ])
    conditions = [ Conditions.UNRELEASED_BAN ]

    server.validateTeam(team, format, conditions).should.be.empty

  it "returns no error if a pokemon has a dream world ability that is the same as a regular ability", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    team[0] = Factory("Metapod", ability: "Shed Skin", moves: [ "Tackle" ])
    conditions = [ Conditions.UNRELEASED_BAN ]

    server.validateTeam(team, format, conditions).should.be.empty

  it "ignores invalid pokemon", ->
    server = new BattleServer()
    format = 'xy1000'
    team = generateTeam()
    team[0] = {species: "I'm a totally fake Pokemon."}
    conditions = [ Conditions.UNRELEASED_BAN ]

    (-> server.validateTeam(team, format, conditions)).should.not.throw()
