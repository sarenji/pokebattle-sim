$ ->
  $mainButtons = $('.main_buttons')
  $mainButtons.on 'click', '.find_battle', ->
    $this = $(this)
    return  if $this.hasClass('disabled')
    teamJSON = JSON.parse(window.localStorage.getItem('team'))
    PokeBattle.socket.send('find battle', teamJSON)
    $this.addClass('disabled')

  $mainButtons.on 'click', '.teambuilder_button', (e) ->
    PokeBattle.navigation.showTeambuilder()

# Depresss Find Battle once one is found
$(window).load ->
  $mainButtons = $('.main_buttons')
  PokeBattle.battles.on 'add', (battle) ->
    if !battle.get('spectating')
      $mainButtons.find('.find_battle').removeClass('disabled')
