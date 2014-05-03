{User} = require('../server/user')
auth = require('../server/auth')
should = require('should')

describe "Users", ->
  describe "#maskName", ->
    it "hides a user's name", ->
      user = new User("a user")
      user = user.maskName("testName")
      user.name.should.equal "testName"

    it "modifies toJSON() to hide name / authority information", ->
      user = new User()
      user.authority = auth.levels.OWNER
      maskedUser = user.maskName("testName")
      maskedJson = maskedUser.toJSON()

      maskedJson.id.should.equal "testName"
      should.not.exist maskedJson.authority