should = require('should')
alts = require('../server/alts')

describe "Alts", ->
  describe '#createAlt', ->
    it 'creates a new alt', (done) ->
      alts.createAlt "player1", "test", (err) ->
        should.not.exist(err)
        alts.listUserAlts "player1", (err, results) ->
          results.length.should.eql 1
          done()

    it 'fails if the alt name is already being used', (done) ->
      alts.createAlt "player1", "test", ->
        alts.createAlt "player1", "test", (err) ->
          should.exist(err)
          done()

    it 'fails if the user already has 5 alts', (done) ->
      alts.createAlt "player1", "test1", (err) ->
        should.not.exist(err)
        alts.createAlt "player1", "test2", (err) ->
          should.not.exist(err)
          alts.createAlt "player1", "test3", (err) ->
            should.not.exist(err)
            alts.createAlt "player1", "test4", (err) ->
              should.not.exist(err)
              alts.createAlt "player1", "test5", (err) ->
                should.not.exist(err)
                alts.createAlt "player1", "test6", (err) ->
                  should.exist(err)
                  done()

  describe '#listUserAlts', ->
    it 'returns the same number of alts that were created', (done) ->
      alts.createAlt "player1", "test1", (err) ->
        alts.createAlt "player1", "test2", (err) ->
          alts.listUserAlts "player1", (err, alts) ->
            ["test1", "test2"].should.eql(alts)
            done()

  describe '#isAltOwnedBy', ->
    it 'returns false if the user does not own the alt', (done) ->
      alts.isAltOwnedBy "player1", "test", (err, result) ->
        should.not.exist(err)
        result.should.be.false

        # make it so another user owns the alt. It should still be false
        alts.createAlt "anotherguy", "test", (err) ->
          should.not.exist(err)
          alts.isAltOwnedBy "player1", "test", (err, result) ->
            should.not.exist(err)
            result.should.be.false
            done()

    it 'returns true if the user owns the alt', (done) ->
      # make it so another user owns the alt. It should still be false
      alts.createAlt "player1", "test", (err) ->
        should.not.exist(err)
        alts.isAltOwnedBy "player1", "test", (err, result) ->
          should.not.exist(err)
          result.should.be.true
          done()

    it 'returns true on null alt name', (done) ->
      alts.isAltOwnedBy "player1", null, (err, result) ->
        result.should.be.true
        done()
