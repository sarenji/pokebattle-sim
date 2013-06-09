{Attachments, Attachment} = require '../server/attachment'

describe "An Attachment list", ->
  class TestAttachment extends Attachment
    name: "TestAttachment"
    maxLayers: 2

  beforeEach ->
    @attachments = new Attachments()

  it "will not add attachments past the maximum stack", ->
    @attachments.push(TestAttachment).should.be.true
    @attachments.push(TestAttachment).should.be.true
    @attachments.push(TestAttachment).should.be.false
