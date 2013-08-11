class @SidebarView extends Backbone.View
  template: JST['navigation']

  events:
    "click .nav_battles li" : 'focusBattle'
    "click .nav_rooms li"   : 'focusRoom'

  initialize: (attributes) =>
    @currentWindow = null
    @listenTo(BattleTower.battles, 'add', @addBattle)
    @listenTo(BattleTower.battles, 'remove', @removeBattle)
    @listenTo(BattleTower.battles, 'reset', @resetBattles)
    @listenTo(BattleTower.battles, 'change:notifications', @renderNotifications)
    @render()

  render: =>
    @$el.html @template(battles: BattleTower.battles)

  renderNotifications: (battle) =>
    $notifications = @$("[data-battle-id='#{battle.id}'] .notifications")

    # We don't want to display notifications if this window is already focused.
    if @currentWindow.data('battle-id') == battle.id
      battle.set('notifications', 0, silent: true)
      $notifications.addClass('hidden')
      return

    # Show notification count.
    notificationCount = battle.get('notifications')
    $notifications.text(notificationCount)
    $notifications.removeClass('hidden')

  addBattle: (battle) =>
    @$(".header_battles, .nav_battles").show()
    $li = $("""<li class="nav_item fake_link" data-battle-id="#{battle.id}">
      <div class="notifications hidden">0</div>#{battle.id}</li>""")
    $li.appendTo(@$('.nav_battles'))
    $li.click()

  removeBattle: (battle) =>
    @$(".nav_battles [data-battle-id='#{battle.id}']").remove()
    if BattleTower.battles.size() == 0
      @$(".header_battles, .nav_battles").hide()
    # TODO: if active, refocus window to previous battle, or the lobby

  resetBattles: (battles) =>
    for battle in battles
      @addBattle(battle)

  focusBattle: (e) =>
    $this = $(e.currentTarget)
    battleId = $this.data('battle-id')
    console.log "Switching to battle #{battleId}"
    $this.find('.notifications').addClass('hidden')
    $battle = $(""".battle_window[data-battle-id='#{battleId}']""")
    @changeWindowTo($battle, $this)

  focusRoom: (e) =>
    $this = $(e.currentTarget)
    $this.find('.notifications').addClass('hidden')
    # TODO: Remove hardcoding
    $room = $('.chat_window')
    @changeWindowTo($room, $this)

  changeWindowTo: ($toSelector, $navItem) =>
    # Show window, hide others
    $mainContent = $('#main-section')
    $mainContent.children().hide()
    @currentWindow = $toSelector.first()
    @currentWindow.show()

    # Add .active to navigation, remove from others
    @$('.nav_item').removeClass('active')
    $navItem.addClass('active')
