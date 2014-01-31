# eventName should be one of "challenge" or "find battle"
# opts may include whether to enable clauses, for example
@createChallengePane = ($wrapper, eventName, opts) ->
  allTeams = JSON.parse(window.localStorage.getItem('teams'))
  selectedIndex = window.localStorage.getItem('selectedTeamIndex') || 0

  renderCurrentTeam = ($context) ->
    $selectTeam = $context.find('.select-team')
    currentTeam = allTeams[selectedIndex] || allTeams[0]
    html = JST['team_dropdown'](window: window, team: currentTeam)
    $selectTeam.html(html)

  $selectFormat = $wrapper.find(".select-format")
  $wrapper.on 'click', '.find_battle', ->
    $this = $(this)
    format = $selectFormat.data('format')
    if !$this.hasClass('disabled')
      teamJSON = allTeams[selectedIndex].pokemon
      PokeBattle.socket.send('find battle', teamJSON, format)
      $this.addClass('disabled')
      $this.find('.find-icon')
        .addClass('icon-spinner spinner-anim')
        .removeClass("icon-globe")
    else
      PokeBattle.socket.send('cancel find battle', format)

  if allTeams?.length > 0
    renderCurrentTeam($wrapper)
  else
    $selectTeam = $wrapper.find('.select-team')
    $selectTeam.html("You have no teams!")

  $wrapper.find('.select-team').click (e) ->
    allTeams = JSON.parse(window.localStorage.getItem('teams'))
    if allTeams && allTeams.length > 0
      html = JST['team_dropdown'](window: window, teams: allTeams)
      $('#main-section .team-dropdown').html(html)

  $wrapper.on 'click', '.select-team-dropdown-item', (e) ->
    slot = $(e.currentTarget).data('slot')
    selectedIndex = slot
    renderCurrentTeam($wrapper)

  # Selecting the format changes the dropdown.
  $wrapper.on 'click', '.select-format-dropdown-item', (e) ->
    $target = $(e.currentTarget)
    format = $target.data('format')
    $selectFormat.text($target.text())
    $selectFormat.data('format', format)

  # Auto-select first available format.
  $wrapper.find('.format-dropdown a').first().click()
