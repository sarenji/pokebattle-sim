@BattleTower ?= {}

@BattleTower.changeWindowTo = ($toSelector) ->
  $mainContent = $('#main-section')
  $mainContent.children().hide()
  $toSelector.show()
