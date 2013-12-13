restify = require('restify')

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
        data.should.be.an.instanceOf(Array)
        data.length.should.be.greaterThan(0)
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
        data.should.be.an.instanceOf(Array)
        data.should.eql([["Smeargle", "default"]])
        done()

  describe '/xy/abilities', ->
    it 'should get an array of abilities back', (done) ->
      @client.get '/xy/abilities', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Array)
        data.length.should.be.greaterThan(0)
        done()

  describe '/xy/abilities/:name', ->
    it 'should get an array of pokemon that have that ability', (done) ->
      @client.get '/xy/abilities/air-lock', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Array)
        data.should.eql([["Rayquaza", "default"]])
        done()

  describe '/xy/types', ->
    it 'should get an array of all available types', (done) ->
      @client.get '/xy/types', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Array)
        data.should.include("Fairy")
        done()

  describe '/xy/types/:name', ->
    it 'should get an array of pokemon that have that type', (done) ->
      @client.get '/xy/types/water', (err, req, res, data) ->
        throw new Error(err)  if err
        data.should.be.an.instanceOf(Array)
        data.should.includeEql(["Greninja", "default"])
        done()
