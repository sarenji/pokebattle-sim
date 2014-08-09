require './helpers'

values = require('../shared/pokebattle_values')
{GenerationJSON} = require '../server/generations'

describe "determining PBV", ->
  it "returns the total PBV for a single Pokemon", ->
    pokemon = {species: "Charizard"}
    pbv = GenerationJSON.XY.FormeData[pokemon.species].default.pokeBattleValue
    values.determinePBV(GenerationJSON.XY, pokemon).should.equal(pbv)

  it "takes mega formes into account", ->
    pokemon = {species: "Charizard", item: "Charizardite X"}
    pbv = GenerationJSON.XY.FormeData[pokemon.species]['mega-x'].pokeBattleValue
    values.determinePBV(GenerationJSON.XY, pokemon).should.equal(pbv)

  it "does not count items that do not match the species", ->
    pokemon = {species: "Charizard", item: "Blazikenite"}
    pbv = GenerationJSON.XY.FormeData[pokemon.species].default.pokeBattleValue
    values.determinePBV(GenerationJSON.XY, pokemon).should.equal(pbv)

  it "adds +15 PBV to a baton passer", ->
    pokemon = {species: "Blaziken"}
    base = values.determinePBV(GenerationJSON.XY, pokemon)

    pokemon.moves = [ "Baton Pass" ]
    values.determinePBV(GenerationJSON.XY, pokemon).should.equal(base + 15)

  it "doubles the more passers the team has", ->
    pokemon = [{species: "Blaziken"}, {species: "Espeon"}]
    base = values.determinePBV(GenerationJSON.XY, pokemon)

    pokemon.forEach((p) -> p.moves = [ "Baton Pass" ])
    values.determinePBV(GenerationJSON.XY, pokemon).should.equal(base + 30)

    pokemon = ({species: "Blaziken"}  for x in [0...6])
    base = values.determinePBV(GenerationJSON.XY, pokemon)

    pokemon.forEach((p) -> p.moves = [ "Baton Pass" ])
    values.determinePBV(GenerationJSON.XY, pokemon).should.equal(base + 480)
