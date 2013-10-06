allTeams = JSON.parse(window.localStorage.getItem('teams'))
selectedIndex = window.localStorage.getItem('selectedTeamIndex') || 0

$ ->
  $mainButtons = $('.main_buttons')
  $mainButtons.on 'click', '.find_battle', ->
    $this = $(this)
    return  if $this.hasClass('disabled')
    teamJSON = allTeams[selectedIndex].pokemon
    PokeBattle.socket.send('find battle', teamJSON)
    $this.addClass('disabled')

  $mainButtons.on 'click', '.teambuilder_button', (e) ->
    PokeBattle.navigation.showTeambuilder()

  if allTeams?.length > 0
    renderCurrentTeam()
  else
    $selectTeam = $('.select-team .well')
    $selectTeam.html("You have no teams!")

  $mainButtons.find('.select-team').click (e) ->
    allTeams = JSON.parse(window.localStorage.getItem('teams'))
    if allTeams && allTeams.length > 0
      html = JST['team_dropdown'](window: window, teams: allTeams)
      $('#main-section .team-dropdown').html(html)

  $mainButtons.on 'click', '.select-team-dropdown-item', (e) ->
    slot = $(e.currentTarget).data('slot')
    selectedIndex = slot
    renderCurrentTeam()

renderCurrentTeam = ->
  $selectTeam = $('.select-team .well')
  currentTeam = allTeams[selectedIndex] || allTeams[0]
  html = JST['team_dropdown'](window: window, team: currentTeam)
  $selectTeam.html(html)

# Depresss Find Battle once one is found
$(window).load ->
  $mainButtons = $('.main_buttons')
  PokeBattle.battles.on 'add', (battle) ->
    if !battle.get('spectating')
      $mainButtons.find('.find_battle').removeClass('disabled')
