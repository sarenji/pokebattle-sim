PokeBattle.primus.on 'version', (version) ->
  if version != PokeBattle.CLIENT_VERSION
    $modal = PokeBattle.modal 'modals/new_client', ($modal) ->
      $modal.on 'click', '.button_refresh', ->
        window.location.reload(true)
    $modal.find('button').first().focus()
