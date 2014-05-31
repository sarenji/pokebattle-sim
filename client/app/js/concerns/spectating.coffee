$(document).on 'click', '.spectate', ->
  battleId = $(this).data('battle-id')
  PokeBattle.primus.send('spectateBattle', battleId)
  return false
