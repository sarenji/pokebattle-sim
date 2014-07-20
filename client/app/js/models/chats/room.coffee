class @Room extends Backbone.AssociatedModel
  relations: [
    type: Backbone.Many
    key:  'users'
    relatedModel: 'User'
    collectionType: 'UserList'
  ]

  EVENTS: "userMessage rawMessage announce clear".split(/\s+/)

  for eventName in this::EVENTS
    do (eventName) =>
      this::[eventName] = (args...) ->
        @trigger(eventName, args...)

  sendChat: (message) ->
    return false  unless message?.replace(/\s+$/).length > 0
    if !PokeBattle.commands.execute(this, message)
      PokeBattle.primus.send('sendChat', @id, message)
    return true
