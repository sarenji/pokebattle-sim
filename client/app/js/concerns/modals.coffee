# domId is optional:
#
# PokeBattle.modal(modalPath, [domId], options, initialize)
PokeBattle.modal = (modalPath, domId, options, initialize) ->
  [domId, options, initialize] = [null, domId, options]  if !_.isString(domId)
  [options, initialize] = [{}, options]  if _.isFunction(options)
  $modal = $(JST[modalPath](options))
  id = '#' + (domId || $modal.prop('id'))
  if $(id).length == 0
    $modal.appendTo($('body'))
    initialize?($modal)
  else
    $modal = $(id).last()
  $modal.modal('show')
  return $modal
