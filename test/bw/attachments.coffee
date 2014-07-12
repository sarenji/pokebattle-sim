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
      @attachments.attachments.push(new Attachment.Embargo())
      @attachments.attachments.push(new Attachment.Yawn())
      @attachments.attachments.push(new Attachment.Ingrain())
      @attachments.attachments.push(new Attachment.AquaRing())
      @attachments.attachments.push(new Attachment.Disable())
      @attachments.attachments.push(new Attachment.Torment())
      @attachments.attachments.push(new Attachment.Substitute())
      @attachments.attachments.push(new Attachment.Curse())
      @attachments.attachments.push(new Attachment.LeechSeed())
      @attachments.attachments.push(new Attachment.MagnetRise())
      @attachments.attachments.push(new Attachment.LockOn())
      @attachments.attachments.push(new Attachment.Confusion())

    it "returns an array of passable attachments already attached", ->
      attachments = @attachments.getPassable()
      attachments.should.not.containEql(Attachment.Disable)
      attachments.should.not.containEql(Attachment.Torment)
      attachments.should.not.containEql(Attachment.Yawn)
      attachments.should.containEql(Attachment.Ingrain)
      attachments.should.containEql(Attachment.AquaRing)
      attachments.should.containEql(Attachment.Embargo)
      attachments.should.containEql(Attachment.Substitute)
      attachments.should.containEql(Attachment.Curse)
      attachments.should.containEql(Attachment.LeechSeed)
      attachments.should.containEql(Attachment.LockOn)
