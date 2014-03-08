{_} = require('underscore')

orderByPriority = (arrayOfAttachments, eventName) ->
  Priorities = require('./priorities')
  return _.clone(arrayOfAttachments)  if eventName not of Priorities
  array = arrayOfAttachments.map (attachment) ->
    [ attachment, Priorities[eventName].indexOf(attachment.constructor) ]
  array.sort((a, b) -> a[1] - b[1])
  array.map((a) -> a[0])

queryUntil = (funcName, conditional, attachments, args...) ->
  for attachment in orderByPriority(attachments, funcName)
    continue  if !attachment.valid()
    if funcName of attachment
      result = attachment[funcName].apply(attachment, args)
    break  if conditional(result)
  result

module.exports = Query = (funcName, args...) ->
  queryUntil(funcName, (-> false), args...)

Query.untilTrue = (funcName, args...) ->
  conditional = (result) -> result == true
  queryUntil(funcName, conditional, args...)

Query.untilFalse = (funcName, args...) ->
  conditional = (result) -> result == false
  queryUntil(funcName, conditional, args...)

Query.untilNotNull = (funcName, args...) ->
  conditional = (result) -> result?
  queryUntil(funcName, conditional, args...)

Query.chain = (funcName, attachments, result, args...) ->
  for attachment in orderByPriority(attachments, funcName)
    continue  if !attachment.valid()
    result = attachment[funcName].call(attachment, result, args...)  if funcName of attachment
  result

Query.modifiers = (funcName, attachments, args...) ->
  result = 0x1000
  for attachment in orderByPriority(attachments, funcName)
    continue  unless funcName of attachment && attachment.valid()
    modifier = attachment[funcName].apply(attachment, args)
    result = Math.floor((result * modifier + 0x800) / 0x1000)
  result
