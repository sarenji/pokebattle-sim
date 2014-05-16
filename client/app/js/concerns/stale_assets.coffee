PokeBattle.events.on 'version', (version) ->
  if version != PokeBattle.CLIENT_VERSION
    PokeBattle.modal 'modals/new_client', ($modal) ->
      $modal.on 'click', '.button_refresh', ->
        window.location.reload(true)
