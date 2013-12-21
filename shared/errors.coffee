self = (module?.exports || window.PokeBattle.errors = {})

errors = """
FIND_BATTLE
BATTLE_DNE
INVALID_SESSION
"""
for error, i in errors.trim().split(/\s+/)
  self[error] = (i + 1)  # Let's not start at 0, just in case.
