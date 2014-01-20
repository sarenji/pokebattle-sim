require '../helpers'

{Ability} = require('../../server/bw/data/abilities')
{Item} = require('../../server/bw/data/items')
{Attachment, Status} = require('../../server/bw/attachment')
Priorities = require('../../server/bw/priorities')
Query = require('../../server/bw/queries')
shared = require('../shared')

describe "BW Priorities:", ->
  ensureAttachments = (arrayOfAttachments, eventName) ->
    attachments = (a  for a in arrayOfAttachments when a.prototype[eventName]? && a not in Priorities[eventName])
    attachments = attachments.map((a) -> a.displayName || a::name)
    if attachments.length > 0
      throw new Error("#{attachments.join(', ')} must specify their #{eventName} priority.")

  it "ensures all relevant attachments have their specified event names", ->
    for eventName of Priorities
      ensureAttachments((klass  for name, klass of Attachment), eventName)
      ensureAttachments((klass  for name, klass of Item), eventName)
      ensureAttachments((klass  for name, klass of Ability), eventName)

  describe "Queries", ->
    it "execute priorities in order", ->
      shared.create.call(this)
      @battle.attach(Attachment.TrickRoom)
      @team2.attach(Attachment.Reflect)
      @p1.attach(Attachment.Ingrain)
      spy1 = @sandbox.spy(Attachment.TrickRoom.prototype, 'endTurn')
      spy2 = @sandbox.spy(Attachment.Reflect.prototype, 'endTurn')
      spy3 = @sandbox.spy(Attachment.Ingrain.prototype, 'endTurn')

      Query("endTurn", @battle.getAllAttachments())
      spy3.calledBefore(spy2).should.be.true
      spy2.calledBefore(spy1).should.be.true
