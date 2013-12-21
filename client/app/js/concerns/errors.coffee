PokeBattle.socket.on "error", (socket, type, args...) ->
  e = PokeBattle.errors
  switch type
    when e.INVALID_SESSION
      window.location = "//pokebattle.com/accounts/login"
    when e.FIND_BATTLE
      PokeBattle.events.trigger("find battle canceled")

      # Show errors
      [errors] = args
      alert(errors)
    else
      console.log("Received error: #{type}")
      console.log("  with content: #{args}")
