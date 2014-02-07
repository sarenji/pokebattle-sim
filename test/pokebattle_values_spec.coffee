require './helpers'

values = require('../shared/pokebattle_values')
{GenerationJSON} = require '../server/generations'

describe "determining PBV", ->
  it "returns the total PBV for a single Pokemon", ->
    pokemon = {name: "Charizard"}
    pbv = 175
    values.determinePBV(GenerationJSON.XY, pokemon).should.equal(pbv)

  it "takes mega formes into account", ->
    pokemon = {name: "Charizard", item: "Charizardite X"}
    pbv = 210
    values.determinePBV(GenerationJSON.XY, pokemon).should.equal(pbv)

  it "does not count items that do not match the species", ->
    pokemon = {name: "Charizard", item: "Blazikenite"}
    pbv = 175
    values.determinePBV(GenerationJSON.XY, pokemon).should.equal(pbv)
