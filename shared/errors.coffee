self = (module?.exports || window.PokeBattle.errors = {})

errors = """
FIND_BATTLE
BATTLE_DNE
INVALID_SESSION
BANNED
COMMAND_ERROR
PRIVATE_MESSAGE
INVALID_ALT_NAME
"""
for error, i in errors.trim().split(/\s+/)
  self[error] = (i + 1)  # Let's not start at 0, just in case.
