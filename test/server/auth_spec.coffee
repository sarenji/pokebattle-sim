auth = require("../../server/auth")

describe "Authorization", ->
  describe "setAuth", ->
    it "changes/gets the auth level for a user", (done) ->
      username = "a user"
      auth.setAuth username, auth.levels.MOD, ->
        auth.getAuth username, (err, level) ->
          level.should.equal(auth.levels.MOD)
          done()

  describe "getAuth", ->
    it "returns the default auth of a user if non-existent", (done) ->
      auth.getAuth "derpa", (err, level) ->
        level.should.equal(auth.levels.USER)
        done()
