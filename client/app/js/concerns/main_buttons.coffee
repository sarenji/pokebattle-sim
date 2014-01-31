allTeams = JSON.parse(window.localStorage.getItem('teams'))
selectedIndex = window.localStorage.getItem('selectedTeamIndex') || 0

$ ->
  $mainButtons = $('.main_buttons')

  $mainButtons.on 'click', '.teambuilder_button', (e) ->
    PokeBattle.navigation.showTeambuilder()

  createChallengePane($mainButtons)

# Depresss Find Battle once one is found
depressFindBattle = ->
  $button = $('.find_battle')
  $button.removeClass("disabled")
  $button.find('.find-icon')
    .removeClass("icon-spinner spinner-anim")
    .addClass("icon-globe")

$(window).load ->
  $mainButtons = $('.main_buttons')
  PokeBattle.battles.on 'add', (battle) ->
    if !battle.get('spectating')
      depressFindBattle()

  PokeBattle.events.on 'find battle canceled', depressFindBattle
