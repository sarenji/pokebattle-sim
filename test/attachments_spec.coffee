{Attachments, Attachment} = require '../server/attachment'
should = require 'should'

describe "An Attachment list", ->
  class TestAttachment extends Attachment
    name: "TestAttachment"
    maxLayers: 2

  class OtherAttachment extends Attachment
    name: "OtherAttachment"

  beforeEach ->
    @attachments = new Attachments()

  it "will not add attachments past the maximum stack", ->
    should.exist @attachments.push(TestAttachment)
    should.exist @attachments.push(TestAttachment)
    should.not.exist @attachments.push(TestAttachment)

  describe '#unattach', ->
    it "removes the current attachment", ->
      @attachments.push(TestAttachment)
      @attachments.unattach(TestAttachment)
      @attachments.attachments.should.have.length(0)

    it "does not remove other attachments if none is found", ->
      @attachments.push(TestAttachment)
      @attachments.unattach(OtherAttachment)
      @attachments.attachments.should.have.length(1)
      @attachments.attachments[0].should.be.instanceOf(TestAttachment)
