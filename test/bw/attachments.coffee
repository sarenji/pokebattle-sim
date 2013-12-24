require '../helpers'

{Attachments, Attachment, BaseAttachment} = require '../../server/bw/attachment'
should = require 'should'

describe "An Attachment list", ->
  class TestAttachment extends BaseAttachment
    name: "TestAttachment"
    maxLayers: 2

  class OtherAttachment extends BaseAttachment
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

  describe '#unattachAll', ->
    it 'is never passed an undefined attachment', ->
      stub = @sandbox.stub().returns(true)
      @attachments.push(TestAttachment)
      @attachments.push(OtherAttachment)
      (=> @attachments.unattachAll(stub)).should.not.throw()
      stub.calledWithMatch(undefined).should.be.false
      stub.calledWithMatch(null).should.be.false
      @attachments.attachments.should.be.empty

  describe '#getPassable', ->
    beforeEach ->
      @attachments.push(Attachment.Embargo)
      @attachments.push(Attachment.Yawn)
      @attachments.push(Attachment.Ingrain)
      @attachments.push(Attachment.AquaRing)
      @attachments.push(Attachment.Disable)
      @attachments.push(Attachment.Torment)
      @attachments.push(Attachment.Substitute)
      @attachments.push(Attachment.Curse)
      @attachments.push(Attachment.LeechSeed)
      @attachments.push(Attachment.MagnetRise)
      @attachments.push(Attachment.LockOn)
      @attachments.push(Attachment.Confusion)

    it "returns an array of passable attachments already attached", ->
      attachments = @attachments.getPassable()
      attachments.should.not.include(Attachment.Disable)
      attachments.should.not.include(Attachment.Torment)
      attachments.should.not.include(Attachment.Yawn)
      attachments.should.include(Attachment.Ingrain)
      attachments.should.include(Attachment.AquaRing)
      attachments.should.include(Attachment.Embargo)
      attachments.should.include(Attachment.Substitute)
      attachments.should.include(Attachment.Curse)
      attachments.should.include(Attachment.LeechSeed)
      attachments.should.include(Attachment.LockOn)
