{Attachments, Attachment} = require '../server/attachment'
should = require 'should'

describe "An Attachment list", ->
  class TestAttachment extends Attachment
    name: "TestAttachment"
    maxLayers: 2

  beforeEach ->
    @attachments = new Attachments()

  it "will not add attachments past the maximum stack", ->
    should.exist @attachments.push(TestAttachment)
    should.exist @attachments.push(TestAttachment)
    should.not.exist @attachments.push(TestAttachment)
