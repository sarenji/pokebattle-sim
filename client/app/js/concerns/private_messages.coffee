# Clicking a person's name will open a private message session with that person.
$(document).on 'click', '.open_pm', ->
  $this = $(this)
  message = PokeBattle.messages.add(id: $this.data('user-id'))
  message.trigger('open', message)

# Receive private message events
PokeBattle.events.on 'privateMessage', (fromUserId, messageText) ->
  message = PokeBattle.messages.add(id: fromUserId)
  message.add(fromUserId, messageText)
