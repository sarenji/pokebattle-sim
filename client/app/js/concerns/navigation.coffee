@BattleTower ?= {}

@BattleTower.changeWindowTo = ($toSelector) ->
  $mainContent = $('#main-section')
  $mainContent.children().hide()
  $toSelector.first().show()

$ ->
  $navigation = $('#navigation')

  # Battles
  $navigation.on 'click', '.nav_battles li', (e) ->
    $this = $(e.currentTarget)
    battleId = $this.data('battle-id')
    $battle = $(""".battle_window[data-battle-id='#{battleId}']""")
    BattleTower.changeWindowTo $battle

  # Lobby rooms
  $navigation.on 'click', '.nav_rooms li', (e) ->
    # TODO: Remove hardcoding
    $room = $('.chat_window')
    BattleTower.changeWindowTo $room
