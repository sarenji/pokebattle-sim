class @SidebarView extends Backbone.View
  template: JST['navigation']

  events:
    "click .logo" : "focusLobby"
    "click .nav_battles li" : 'focusBattle'
    "click .nav_rooms li"   : 'focusRoom'
    "click .nav_battles .close" : 'leaveBattle'
    "click .nav_teambuilder": 'showTeambuilder'
    "click .nav_battle_list": 'showBattleList'

  initialize: (attributes) =>
    @currentWindow = null
    @listenTo(PokeBattle.battles, 'add', @addBattle)
    @listenTo(PokeBattle.battles, 'remove', @removeBattle)
    @listenTo(PokeBattle.battles, 'reset', @resetBattles)
    @listenTo(PokeBattle.battles, 'change:notifications', @renderNotifications)
    @render()

  showTeambuilder: =>
    @changeWindowTo($("#teambuilder-section"), $(".nav_teambuilder"))

  showBattleList: =>
    @changeWindowTo($("#battle-list-section"), $(".nav_battle_list"))
    PokeBattle.battleList.refreshList()

  render: =>
    @$el.html @template(battles: PokeBattle.battles)

  renderNotifications: (battle) =>
    $notifications = @$("[data-battle-id='#{battle.id}'] .notifications")

    # We don't want to display notifications if this window is already focused.
    if @currentWindow.data('battle-id') == battle.id
      battle.set('notifications', 0, silent: true)
      $notifications.addClass('hidden')
      return

    # Show notification count.
    notificationCount = battle.get('notifications')
    if notificationCount > 0
      $notifications.text(notificationCount)
      $notifications.removeClass('hidden')
    else
      $notifications.addClass('hidden')

  addBattle: (battle) =>
    @$(".header_battles, .nav_battles").removeClass("hidden")
    $li = $("""<li class="nav_item fake_link" data-battle-id="#{battle.id}">
      <div class="nav_meta">
        <div class="notifications hidden">0</div>
        <div class="close">x</div>
      </div>#{battle.get('playerIds').join(' VS ')}</li>""")
    $li.appendTo(@$('.nav_battles'))
    $li.click()

  removeBattle: (battle) =>
    $navItems = @$(".nav_item")
    $battle = @$(".nav_item[data-battle-id='#{battle.id}']")
    index = $navItems.index($battle)
    $battle.remove()
    if PokeBattle.battles.size() == 0
      @$(".header_battles, .nav_battles").addClass('hidden')
    $next = $navItems.eq(index - 1)
    $next.click()

  resetBattles: (battles) =>
    for battle in battles
      @addBattle(battle)

  leaveBattle: (e) =>
    $navItem = $(e.currentTarget).closest('.nav_item')
    battleId = $navItem.data('battle-id')
    battle   = PokeBattle.battles.get(battleId)
    if battle.isPlaying()
      return  if !confirm("Are you sure you want to forfeit this battle?")
      battle.forfeit()
    PokeBattle.battles.remove(battle)
    false

  focusBattle: (e) =>
    $this = $(e.currentTarget)
    @resetNotifications($this)
    battleId = $this.data('battle-id')
    @changeWindowToBattle(battleId)

  focusLobby: (e) =>
    # TODO: Clean this up once rooms are implemented
    # right now it duplicates part of focusRoom()
    $lobbyLink = @$(".nav_rooms li").first()
    @resetNotifications($lobbyLink)
    $room = $('.chat_window')
    @changeWindowTo($room, $lobbyLink)
    PokeBattle.router.navigate("")

  focusRoom: (e) =>
    $this = $(e.currentTarget)
    @resetNotifications($this)
    # TODO: Remove hardcoding once rooms are implemented
    $room = $('.chat_window')
    @changeWindowTo($room, $this)
    PokeBattle.router.navigate("")

  changeWindowTo: ($toSelector, $navItem) =>
    # Show window, hide others
    $mainContent = $('#main-section')
    $mainContent.children().addClass("hidden")
    @currentWindow = $toSelector.first()
    @currentWindow.removeClass("hidden")
    @currentWindow.find('.chat').trigger('scroll_to_bottom')

    # Add .active to navigation, remove from others
    @$('.nav_item').removeClass('active')
    $navItem.addClass('active')

  changeWindowToBattle: (battleId) =>
    $battle = $(""".battle_window[data-battle-id='#{battleId}']""")
    $navItem = @$("[data-battle-id='#{battleId}']")
    @changeWindowTo($battle, $navItem)
    PokeBattle.router.navigate("battles/#{battleId}")

  resetNotifications: ($link) =>
    $link = $link.first()
    $link = $link.closest('li')  if $link[0].tagName != 'li'
    if battleId = $link.data('battle-id')
      battle = PokeBattle.battles.get(battleId)
      battle.set('notifications', 0)
