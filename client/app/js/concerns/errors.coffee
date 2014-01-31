PokeBattle.events.on "error", (type, args...) ->
  e = PokeBattle.errors
  switch type
    when e.INVALID_SESSION
      window.location = "//pokebattle.com/accounts/login"
    when e.FIND_BATTLE
      PokeBattle.events.trigger("find battle canceled")

      # Show errors
      [errors] = args
      alert(errors)
    when e.COMMAND_ERROR
      [ message ] = args
      PokeBattle.chatView.updateChat(message)
    when e.PRIVATE_MESSAGE
      [ toUser, messageText ] = args
      message = PokeBattle.messages.get(toUser)
      message.add(toUser, messageText, type: "error")
    else
      console.log("Received error: #{type}")
      console.log("  with content: #{args}")
