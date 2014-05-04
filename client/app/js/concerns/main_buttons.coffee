$ ->
  $mainButtons = $('.main_buttons')

  $mainButtons.on 'click', '.teambuilder_button', (e) ->
    PokeBattle.navigation.showTeambuilder()

  createChallengePane
    eventName: "findBattle"
    populate: $mainButtons.find('.find_battle_select_team')
    button: $mainButtons.find('.find_battle')
    defaultClauses: [
      Conditions.TEAM_PREVIEW
      Conditions.SLEEP_CLAUSE
      Conditions.EVASION_CLAUSE
      Conditions.SPECIES_CLAUSE
      Conditions.OHKO_CLAUSE
      Conditions.UNRELEASED_BAN
      Conditions.PBV_1000
      Conditions.RATED_BATTLE
      Conditions.TIMED_BATTLE
    ]
    blockedClauses: true

  $mainButtons.find('.find_battle').on 'challenge', ->
    $this = $(this)
    $this.find('.find-icon')
      .addClass('icon-spinner spinner-anim')
      .removeClass("icon-globe")

  $mainButtons.find('.display_credits').click ->
    if $('#credits-modal').length == 0
      $('body').append(JST['modals/credits']())
    $modal = $('#credits-modal')
    $modal.modal('show')
    $modal.find('.modal-footer button').first().focus()

# Depresss Find Battle once one is found
depressFindBattle = ->
  $mainButtons = $('.main_buttons')
  $button = $mainButtons.find('.find_battle')
  $button.removeClass("disabled")
  $button.find('.find-icon')
    .removeClass("icon-spinner spinner-anim")
    .addClass("icon-globe")
  $mainButtons.find('.find_battle_select_team .select').removeClass('disabled')

$(window).load ->
  $mainButtons = $('.main_buttons')
  PokeBattle.battles.on 'add', (battle) ->
    if !battle.get('spectating')
      depressFindBattle()

  PokeBattle.events.on 'findBattleCanceled', depressFindBattle
