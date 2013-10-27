allTeams = JSON.parse(window.localStorage.getItem('teams'))
selectedIndex = window.localStorage.getItem('selectedTeamIndex') || 0

$ ->
  $mainButtons = $('.main_buttons')
  $selectFormat = $mainButtons.find(".select-format")
  $mainButtons.on 'click', '.find_battle', ->
    $this = $(this)
    return  if $this.hasClass('disabled')
    teamJSON = allTeams[selectedIndex].pokemon
    format = $selectFormat.data('format')
    PokeBattle.socket.send('find battle', teamJSON, format)
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

  # Selecting the format changes the dropdown.
  $mainButtons.on 'click', '.select-format-dropdown-item', (e) ->
    $target = $(e.currentTarget)
    format = $target.data('format')
    $selectFormat.text($target.text())
    $selectFormat.data('format', format)

  # Auto-select first available format.
  $mainButtons.find('.format-dropdown').children().first().click()


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
