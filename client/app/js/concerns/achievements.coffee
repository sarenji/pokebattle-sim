$currentModal = null

PokeBattle.primus.on 'achievementsEarned', (achievements) ->
  # TODO: Add achievements to the current modal if one is already open
  $currentModal = PokeBattle.modal('modals/achievements', window: window, achievements: achievements)