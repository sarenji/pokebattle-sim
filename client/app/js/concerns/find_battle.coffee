# eventName should be one of "challenge" or "find battle"
# opts may include whether to enable clauses, for example
@createChallengePane = (opts) ->
  $wrapper = opts.populate
  $button = opts.button
  eventName = opts.eventName

  allTeams = JSON.parse(window.localStorage.getItem('teams'))
  selectedIndex = window.localStorage.getItem('selectedTeamIndex') || 0

  renderCurrentTeam = ($context) ->
    $selectTeam = $context.find('.select-team')
    currentTeam = allTeams[selectedIndex] || allTeams[0]
    html = JST['team_dropdown'](window: window, team: currentTeam)
    $selectTeam.html(html)

  $wrapper.html(JST['new_battle']())
  $selectFormat = $wrapper.find(".select-format")
  $button.click ->
    format = $selectFormat.data('format')
    if !$button.hasClass('disabled')
      teamJSON = allTeams[selectedIndex].pokemon
      PokeBattle.socket.send(eventName, teamJSON, format)
      $button.trigger('challenge')
    else
      PokeBattle.socket.send("cancel #{eventName}", format)
      $button.trigger('cancelChallenge')

  if allTeams?.length > 0
    renderCurrentTeam($wrapper)
  else
    $selectTeam = $wrapper.find('.select-team')
    $selectTeam.html("You have no teams!")

  # Clicking the team dropdown brings down a team selection menu.
  $wrapper.find('.select-team').click (e) ->
    allTeams = JSON.parse(window.localStorage.getItem('teams'))
    if allTeams && allTeams.length > 0
      html = JST['team_dropdown'](window: window, teams: allTeams)
      $('#main-section .team-dropdown').html(html)

  # Selecting a team from the menu
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
