{Ability} = require('../../server/xy/data/abilities')
{Item} = require('../../server/xy/data/items')
{Attachment, Status} = require('../../server/xy/attachment')
priority = require('../../server/xy/priorities')
shared = require('../shared')

describe "XY Priorities:", ->
  ensureAttachments = (arrayOfAttachments, eventName) ->
    attachments = (a  for a in arrayOfAttachments when a.prototype[eventName]? && a not in priority.Priorities[eventName])
    attachments = attachments.map((a) -> a.displayName || a::name)
    if attachments.length > 0
      throw new Error("#{attachments.join(', ')} must specify their #{eventName} priority.")

  it "ensures all relevant attachments have their specified event names", ->
    for eventName of priority.Priorities
      ensureAttachments((klass  for name, klass of Attachment), eventName)
      ensureAttachments((klass  for name, klass of Item), eventName)
      ensureAttachments((klass  for name, klass of Ability), eventName)

  describe "#orderByPriority", ->
    it "returns a list of attachments in order", ->
      shared.create.call(this)
      @battle.attach(Attachment.TrickRoom)
      @team2.attach(Attachment.Reflect)
      @p1.attach(Attachment.Ingrain)
      attachments = priority.orderByPriority(@battle.getAllAttachments(), "endTurn")
      attachments = attachments.map((a) -> a.constructor)
      trIndex = attachments.indexOf(Attachment.TrickRoom)
      rIndex = attachments.indexOf(Attachment.Reflect)
      iIndex = attachments.indexOf(Attachment.Ingrain)

      iIndex.should.be.lessThan(rIndex)
      rIndex.should.be.lessThan(trIndex)
