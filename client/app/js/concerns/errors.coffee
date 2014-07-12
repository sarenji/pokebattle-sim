PokeBattle.primus.on 'errorMessage', (args...) ->
  PokeBattle.events.trigger('errorMessage', args...)

PokeBattle.events.on "errorMessage", (type, args...) ->
  e = PokeBattle.errors
  switch type
    when e.INVALID_SESSION
      $('#errors-modal').remove()  if $('#errors-modal').length > 0
      options =
        title: "Your login timed out!"
        body: """To access the simulator, you need to
          <a href="//pokebattle.com/accounts/login">login again</a>."""
      $modal = PokeBattle.modal('modals/errors', options)
      $modal.find('.modal-footer button').first().focus()
      PokeBattle.primus.end()

    when e.BANNED
      $('#errors-modal').remove()  if $('#errors-modal').length > 0
      [reason, length] = args
      if length < 0
        length = "is permanent"
      else
        length = "lasts for #{Math.round(length / 60)} minute(s)"
      body = "This ban #{length}."
      if reason
        body += "You were banned for the following reason: #{reason}"
      options =
        title: "You have been banned!"
        body: body
      $modal = PokeBattle.modal('modals/errors', options)
      $modal.find('.modal-footer button').first().focus()
      PokeBattle.primus.end()

    when e.FIND_BATTLE
      PokeBattle.events.trigger("findBattleCanceled")

      # Show errors
      [errors] = args
      alert(errors)
    when e.COMMAND_ERROR
      [ message ] = args
      PokeBattle.chatView.announce('error', message)
    when e.PRIVATE_MESSAGE
      [ toUser, messageText ] = args
      message = PokeBattle.messages.get(toUser)
      message.add(toUser, messageText, type: "error")
    when e.INVALID_ALT_NAME
      [ messageText ] = args
      alert(messageText)
      PokeBattle.events.trigger("invalidAltName")
    else
      console.log("Received error: #{type}")
      console.log("  with content: #{args}")
