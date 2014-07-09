$(document).on 'click', '.spectate', ->
  battleId = $(this).data('battle-id')
  PokeBattle.router.navigate("battles/#{battleId}", trigger: true)
  return false
