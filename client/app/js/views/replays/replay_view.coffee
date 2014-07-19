class @ReplayView extends Backbone.View
  replayTemplate: JST['replay']

  events:
    'click .delete-replay': 'deleteReplay'

  render: =>
    @$el.empty()

    templates = @collection.map((replay) => @replayTemplate({window, replay}))
    groups = for x in [0...templates.length] by 3
      _.compact([ templates[x], templates[x + 1], templates[x + 2] ])

    for groupHTML in groups
      $row = $('<div/>').addClass('row-fluid')
      $row.append(groupHTML)
      $row.appendTo(@$el)
    this

  deleteReplay: (e) =>
    return  unless confirm("Do you really want to delete this replay?")
    $target = $(e.currentTarget)
    $spinner = $target.closest('.clickable-box').find('.show_spinner')

    $spinner.removeClass('hidden')
    cid = $target.data('cid')
    replay = @collection.get(cid)
    replay
      .destroy()
      .complete(@render)
