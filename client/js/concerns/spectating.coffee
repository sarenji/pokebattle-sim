$(document).on 'click', '.spectate', ->
  battleId = $(this).data('battle-id')
  BattleTower.socket.send('spectate battle', battleId)
