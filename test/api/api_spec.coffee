require '../helpers'

restify = require('restify')
{Factory} = require("../factory")

before (done) ->
  @PORT = 8083
  require('../../api').createServer(@PORT, done)

describe 'XY API:', ->
  beforeEach ->
    @client = restify.createJsonClient
      version: '*'
      url: "http://127.0.0.1:#{@PORT}"

  describe '/xy/items', ->
    it 'should get an array of items back', (done) ->
      @client.get '/xy/items', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("items")
        data.items.length.should.be.greaterThan(0)
        done()

  describe '/xy/moves', ->
    it 'should get a hash of moves back', (done) ->
      @client.get '/xy/moves', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("Tackle")
        done()

  describe '/xy/moves/:name', ->
    it 'should get an array of pokemon that can learn that move', (done) ->
      @client.get '/xy/moves/sketch', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("pokemon")
        data.pokemon.should.eql([["Smeargle", "default"]])
        done()

    it 'takes into account event pokemon', (done) ->
      @client.get '/xy/moves/extremespeed', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("pokemon")
        data.pokemon.should.includeEql(["Genesect", "default"])
        done()

    it 'takes into account pre-evolution moves', (done) ->
      @client.get '/xy/moves/pursuit', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("pokemon")
        data.pokemon.should.includeEql(["Tyranitar", "default"])
        done()

  describe '/xy/abilities', ->
    it 'should get an array of abilities back', (done) ->
      @client.get '/xy/abilities', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("abilities")
        data.abilities.length.should.be.greaterThan(0)
        done()

  describe '/xy/abilities/:name', ->
    it 'should get an array of pokemon that have that ability', (done) ->
      @client.get '/xy/abilities/air-lock', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("pokemon")
        data.pokemon.should.eql([["Rayquaza", "default"]])
        done()

    it "encodes pokemon names properly", (done) ->
      @client.get '/xy/abilities/poison-point', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("pokemon")
        res.headers['content-type'].should.include("charset=utf8")
        data.pokemon.should.includeEql(["Nidoran♀", "default"])
        data.pokemon.should.includeEql(["Nidoran♂", "default"])
        done()

  describe '/xy/types', ->
    it 'should get an array of all available types', (done) ->
      @client.get '/xy/types', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("types")
        data.types.should.include("Fairy")
        done()

  describe '/xy/types/:name', ->
    it 'should get an array of pokemon that have that type', (done) ->
      @client.get '/xy/types/water', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("pokemon")
        data.pokemon.should.includeEql(["Greninja", "default"])
        done()

  describe '/xy/pokemon', ->
    it 'should get forme data for all pokemon', (done) ->
      @client.get '/xy/pokemon', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("Charizard")
        data.should.have.property("Mandibuzz")
        data.should.have.property("Trevenant")
        done()

  describe '/xy/pokemon/:name', ->
    it 'should get species data for that pokemon', (done) ->
      @client.get '/xy/pokemon/charizard', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("default")
        data.should.have.property("mega-x")
        data.should.have.property("mega-y")
        done()

  describe '/xy/pokemon/:name/moves', ->
    it 'should get all moves that pokemon can learn', (done) ->
      @client.get '/xy/pokemon/charizard/moves', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("moves")
        data.moves.should.be.an.instanceOf(Array)
        data.moves.should.include("Fire Blast")
        done()

  describe '/xy/pokemon/:name/:forme/moves', ->
    it 'should get all moves that pokemon in that forme can learn', (done) ->
      @client.get '/xy/pokemon/rotom/wash/moves', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Object)
        data.should.have.property("moves")
        data.moves.should.be.an.instanceOf(Array)
        data.moves.should.include("Hydro Pump")
        data.moves.should.not.include("Overheat")
        done()

  describe '/xy/damagecalc', ->
    it 'should calculate damage properly', (done) ->
      params =
        move: "Fire Punch"
        attacker: Factory("Hitmonchan", {
            nature: "Adamant"
            ability: "Iron Fist"
            evs: {attack: 252}
            item: "Life Orb"
          })
        defender: Factory("Hitmonlee")

      @client.put '/xy/damagecalc', params, (err, req, res, data) ->
        throw new Error(err)  if err
        data.min.damage.should.equal(200)
        data.max.damage.should.equal(236)
        done()
