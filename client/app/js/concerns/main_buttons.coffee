$ ->
  $mainButtons = $('.main_buttons')
  $mainButtons.on 'click', '.find_battle', ->
    $this = $(this)
    return  if $this.hasClass('disabled')
    BattleTower.socket.send('find battle')
    $this.addClass('disabled')

# Depresss Find Battle once one is found
$(window).load ->
  $mainButtons = $('.main_buttons')
  BattleTower.battles.on 'add', (battle) ->
    if !battle.get('spectating')
      $mainButtons.find('.find_battle').removeClass('disabled')
