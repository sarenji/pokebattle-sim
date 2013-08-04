$ ->
  $mainNav = $('.main_nav')
  $mainNav.on 'click', '.find_battle', ->
    $this = $(this)
    return  if $this.hasClass('disabled')
    BattleTower.socket.send('find battle')
    $this.addClass('disabled')
