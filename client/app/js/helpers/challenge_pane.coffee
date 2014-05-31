# eventName should be one of "challenge" or "find battle"
# opts may include whether to enable clauses, for example
@createChallengePane = (opts) ->
  $wrapper = opts.populate
  $button = opts.button
  $accept = opts.acceptButton || $()
  $reject = opts.rejectButton || $()
  $buttons = $button.add($accept).add($reject)
  eventName = opts.eventName
  capitalizedEventName = "#{eventName[0].toUpperCase()}#{eventName.substr(1)}"
  acceptEventName = "accept#{capitalizedEventName}"
  rejectEventName = "reject#{capitalizedEventName}"
  cancelEventName = "cancel#{capitalizedEventName}"
  generation = opts.generation
  personId = opts.personId
  defaultClauses = opts.defaultClauses || []
  blockedClauses = opts.blockedClauses ? false

  selectedTeamId = null
  selectedAlt = null

  getSelectedTeam = ->
    PokeBattle.TeamStore.get(selectedTeamId) || PokeBattle.TeamStore.at(0)

  renderCurrentTeam = ($context) ->
    $selectTeam = $context.find('.select-team')
    if PokeBattle.TeamStore.length > 0
      currentTeam = getSelectedTeam()
      html = JST['team_dropdown'](window: window, team: currentTeam)
      $selectTeam.html(html)
    else
      $selectTeam.html("You have no teams!")

  cancelChallenge = ->
    enableButtons()
    if personId
      PokeBattle.primus.send(cancelEventName, personId)
    else
      format = $selectFormat.data('format')
      PokeBattle.primus.send(cancelEventName, format)
    $button.trigger('cancelChallenge')

  disableButtons = ->
    $wrapper.find('.select').addClass('disabled')
    $buttons.addClass('disabled')

  # Enable buttons
  enableButtons = ->
    $buttons.removeClass('disabled')

  toggleAltInput = (visible) ->
    $wrapper.find('.alt-input').toggleClass("hidden", !visible)
    $wrapper.find('.alt-dropdown-section').toggleClass("hidden", visible)
    $wrapper.find('.alt-input input').focus()  if visible

  isAttachedToDom = ->
    $.contains(document, $wrapper.get(0))

  altCreatedEvent = ->
    return PokeBattle.primus.off('altCreated', altCreatedEvent)  unless isAttachedToDom()
    $wrapper.find('.alt-input input').val("")
    toggleAltInput(false)

  PokeBattle.primus.on 'altCreated', altCreatedEvent

  enableButtons()

  $wrapper.html(JST['new_battle']({window, defaultClauses}))
  $selectFormat = $wrapper.find(".select-format")
  # Implement finding battle/challenging
  $button.on 'click.challenge', ->
    # Start requesting for notify permission here
    PokeBattle.requestNotifyPermission()

    format = $selectFormat.data('format')
    # Toggle state when you press the button.
    if !$button.hasClass('disabled')
      disableButtons()
      team = getSelectedTeam()
      teamJSON = team.toNonNullJSON().pokemon
      # Send the event
      if personId
        $clauses = $wrapper.find('input:checked[type="checkbox"]')
        clauses = []
        $clauses.each(-> clauses.push(parseInt($(this).val(), 10)))
        PokeBattle.primus.send(eventName, personId, format, teamJSON, clauses, selectedAlt)
      else
        PokeBattle.primus.send(eventName, format, teamJSON, selectedAlt)
      $button.addClass('disabled').trigger('challenge')
    else
      cancelChallenge()

  # Implement accept/reject buttons.
  $accept.on 'click.challenge', ->
    return  if $(this).hasClass('disabled')
    disableButtons()
    teamJSON = getSelectedTeam().toNonNullJSON().pokemon
    PokeBattle.primus.send(acceptEventName, personId, teamJSON, selectedAlt)

  $reject.on 'click.challenge', ->
    return  if $(this).hasClass('disabled')
    disableButtons()
    PokeBattle.primus.send(rejectEventName, personId)

  # Clicking the alts dropdown brings down an alt selection dropdown menu
  $wrapper.find('.select-alt').click (e) ->
    html = JST['alt_dropdown'](alts: PokeBattle.alts.list, username: PokeBattle.username)
    $wrapper.find('.alt-dropdown').html(html)

  # Selecting an alt from the dropdown 
  $wrapper.find('.alt-dropdown').on 'click', '.select-alt-dropdown-item', (e) ->
    selectedAlt = $(this).data('alt-name')
    $wrapper.find('.select-alt').html($(this).html())

  # When add alt is clicked, show the alt input form
  $wrapper.find('.alt-dropdown').on 'click', '.add-alt-dropdown-item', (e) ->
    toggleAltInput(true)

  # Clicking the Add Alt Button
  $wrapper.find('.alt-input .add-button').click (e) ->
    altName = $wrapper.find('.alt-input input').val().trim()
    PokeBattle.alts.createAlt(altName)

  # Clicking the Cancel Add Alt Button
  $wrapper.find('.alt-input .cancel-button').click (e) ->
    toggleAltInput(false)

  # Clicking the team dropdown brings down a team selection menu.
  # Also updates the allTeams collection
  $wrapper.find('.select-team').click (e) ->
    allTeams = PokeBattle.TeamStore.models
    if allTeams && allTeams.length > 0
      html = JST['team_dropdown'](window: window, teams: allTeams)
      $wrapper.find('.team-dropdown').html(html)

  # Selecting a team from the menu
  $wrapper.find('.team-dropdown').on 'click', '.select-team-dropdown-item', (e) ->
    slot = $(e.currentTarget).data('slot')
    selectedTeamId = PokeBattle.TeamStore.at(slot).id
    renderCurrentTeam($wrapper)

  # Selecting the format changes the dropdown.
  $wrapper.find('.format-dropdown').on 'click', '.select-format-dropdown-item', (e) ->
    $target = $(e.currentTarget)
    format = $target.data('format')
    $selectFormat.text($target.text())
    $selectFormat.data('format', format)
  
  # Select non-alt option
  $wrapper.find('.select-alt').html(JST['alt_dropdown'](alt: null, username: PokeBattle.username))

  # Auto-select format.
  if generation
    # If a generation is passed, auto-select it.
    $format = $wrapper.find(".format-dropdown a[data-format='#{generation}']")
    $format.first().click()
    $wrapper.find('.select-format').addClass('disabled')
  else
    # Auto-select first available format.
    $wrapper.find('.format-dropdown a').first().click()

  if blockedClauses
    $checkboxes = $wrapper.find('input[type="checkbox"]')
    if blockedClauses != true
      $checkboxes = $checkboxes.filter ->
        clause = Number($(this).data('clause'))
        clause in blockedClauses
    $checkboxes.prop('disabled', true)
    $checkboxes.closest('label').addClass('disabled')

  renderCurrentTeam($wrapper)

  # Called when a team has been updated
  teamUpdated = ->
    # If this challenge panel no longer exists, remove the callback
    if not isAttachedToDom()
      PokeBattle.TeamStore.off 'add remove reset saved', teamUpdated
      return

    # Rerender the current team
    renderCurrentTeam($wrapper)

  # Start listening for team updated events
  PokeBattle.TeamStore.on 'add remove reset saved', teamUpdated
