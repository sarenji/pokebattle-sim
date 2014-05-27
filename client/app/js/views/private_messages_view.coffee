class @PrivateMessagesView extends Backbone.View
  messageTemplate: JST['private_message']

  events:
    "keypress .chat_input"  : "keyPressEvent"
    "keyup .chat_input"  : "keyUpEvent"
    "click .challenge_button, .cancel_challenge" : "toggleChallengeEvent"
    "click .popup_messages" : "focusChatEvent"
    "click .title_minimize" : "minimizePopupEvent"
    "click .title_close" : "closePopupEvent"
    "challenge .popup" : "sendChallengeEvent"
    "cancelChallenge .popup" : "challengeCanceledEvent"
    "focus .popup" : "focusPopupEvent"

  initialize: =>
    @numPopups = 0
    @listenTo(@collection, 'open', @createPopup)
    @listenTo(@collection, 'focus', @focusPopup)
    @listenTo(@collection, 'receive', @receiveMessage)
    @listenTo(@collection, 'close', @closePopup)
    @listenTo(@collection, 'minimize', @minimizePopup)
    @listenTo(@collection, 'show', @showPopup)
    @listenTo(@collection, 'openChallenge', @openChallenge)
    @listenTo(@collection, 'cancelChallenge', @cancelChallenge)
    @listenTo(@collection, 'closeChallenge', @closeChallenge)
    @listenTo(@collection, 'focus show', @resetNotifications)

    @listenTo(PokeBattle.userList, 'add', @notifyJoin)
    @listenTo(PokeBattle.userList, 'remove', @notifyLeave)

  createPopup: (message) =>
    title = id = message.id
    $html = @$findPopup(id)
    if @$findPopup(id).length == 0
      $html = $(@messageTemplate({window, id, title}))

      @$el.append($html)
      @positionPopup($html, @numPopups)
      @addLogMessages($html, message.getLog())
      @numPopups += 1
    $html

  focusPopup: (message) =>
    id = message.id
    $popup = @$findPopup(id)
    $popup.find('.chat_input').focus()

  closePopup: (message) =>
    username = message.id
    @$findPopup(username).remove()
    @repositionPopups()
    @numPopups -= 1

  minimizePopup: (message) =>
    username = message.id
    $popup = @$findPopup(username)
    $popup.addClass('hidden')

  showPopup: (message) =>
    username = message.id
    $popup = @$findPopup(username)
    $popup.removeClass('hidden')

  # todo: make this and receiveMessage construct messages from a common source
  addLogMessages: ($popup, log) =>
    messageHtml = ""
    for {username, message, opts} in log 
      if opts.type == 'error'
        messageHtml += "<p class='privmsg-error log-message'>#{message}</p>"
      else if opts.type == 'alert'
        messageHtml += "<p class='privmsg-alert log-message'>#{message}</p>"
      else
        messageHtml += "<p class='log-message'><strong>#{username}:</strong> #{message}</p>"

    $messages = $popup.find('.popup_messages').append($(messageHtml))
    @scrollToBottom($popup)

  # todo: make this and addLogMessages construct messages from a common source
  receiveMessage: (messageModel, messageId, username, message, options) =>
    $popup = @$findOrCreatePopup(messageId)
    $messages = $popup.find('.popup_messages')
    wasAtBottom = @isAtBottom($popup)
    if options.type == 'error'
      $messages.append("<p class='privmsg-error'>#{message}</p>")
    else if options.type == 'alert'
      $messages.append("<p class='privmsg-alert'>#{message}</p>")
    else
      if username != "Me" && !$popup.find('.chat_input').is(":focus")
        $popup.addClass('new_message')
        PokeBattle.notifyUser(PokeBattle.NotificationTypes.PRIVATE_MESSAGE, username)
      else
        @resetNotifications(messageModel)
      $messages.append("<p><strong>#{username}:</strong> #{message}</p>")
    if wasAtBottom then @scrollToBottom($popup)

  openChallenge: (messageId, generation, conditions) =>
    $popup = @$findOrCreatePopup(messageId)
    $challenge = @createChallenge($popup, generation, conditions)
    if generation
      $challenge.find('.is_not_challenger').addClass('hidden')
      $challenge.find('.is_challenger').removeClass('hidden')

  cancelChallenge: (messageId) =>
    $popup = @$findOrCreatePopup(messageId)
    $challenge = $popup.find('.challenge')
    $challenge.find('.icon-spinner').addClass('hidden')
    $challenge.find('.send_challenge, .select').removeClass('disabled')
    $challenge.find('.challenge_text').text("Challenge")
    $challenge.find(".cancel_challenge").text('Close')

  closeChallenge: (messageId) =>
    $popup = @$findOrCreatePopup(messageId)
    $challenge = $popup.find('.challenge')
    $challenge.addClass('hidden')
    $popup.find('.popup_messages').removeClass('small')

  resetNotifications: (message) =>
    message.set('notifications', 0)

  notifyJoin: (user) =>
    message = @collection.get(user.id)
    return  unless @isOpen(message)
    message?.add(user.id, "#{user.id} is now online!", type: "alert")

  notifyLeave: (user) =>
    message = @collection.get(user.id)
    return  unless @isOpen(message)
    message?.add(user.id, "#{user.id} is now offline.", type: "alert")

  isOpen: (message) =>
    message && @$findPopup(message.id).length > 0

  # Returns true if the chat is scrolled to the bottom of the screen.
  # This also returns true if the messages are hidden.
  isAtBottom: ($popup) =>
    $el = $popup.find('.popup_messages')
    ($el[0].scrollHeight - $el.scrollTop() <= $el.outerHeight())

  scrollToBottom: ($popup) =>
    messages = $popup.find('.popup_messages')[0]
    messages.scrollTop = messages.scrollHeight
    false

  positionPopup: ($popup, index) =>
    leftOffset = $('#content').position().left
    $popup.css(left: leftOffset + index * $popup.outerWidth(true))

  repositionPopups: =>
    @$(".popup").each (index, self) =>
      @positionPopup($(self), index)

  $findPopup: (id) =>
    @$(".popup[data-user-id='#{id}']")

  $findOrCreatePopup: (messageId) =>
    $popup = @$findPopup(messageId)
    $popup = @createPopup(@collection.get(messageId))  if $popup.length == 0
    $popup

  $closestPopup: (target) =>
    $target = $(target)
    return $target  if $target.hasClass("popup")
    return $target.closest(".popup")

  messageFromPopup: (target) =>
    $popup = @$closestPopup(target)
    message = @collection.get($popup.data('user-id'))
    return message

  createChallenge: ($popup, generation, conditions) =>
    $challenge = $popup.find('.challenge')
    $challenge.html(JST['challenge']())
    createChallengePane
      eventName: "challenge"
      button: $popup.find('.send_challenge')
      acceptButton: $popup.find('.accept_challenge')
      rejectButton: $popup.find('.reject_challenge')
      populate: $popup.find(".challenge_data")
      generation: generation
      personId: $popup.data('user-id')
      defaultClauses: conditions || [
        Conditions.TEAM_PREVIEW
        Conditions.PBV_1000
        Conditions.SLEEP_CLAUSE
        Conditions.EVASION_CLAUSE
        Conditions.SPECIES_CLAUSE
        Conditions.OHKO_CLAUSE
        Conditions.PRANKSTER_SWAGGER_CLAUSE
        Conditions.UNRELEASED_BAN
      ]
      blockedClauses: conditions? || [Conditions.RATED_BATTLE]
    $popup.find('.popup_messages').addClass('small')
    $challenge.removeClass('hidden')
    $challenge

  ##########
  # EVENTS #
  ##########

  keyPressEvent: (e) =>
    switch e.which
      when 13 # [ Enter ]
        $input = $(e.currentTarget)
        message = @messageFromPopup(e.currentTarget)
        text = $input.val()
        return  if text.length == 0
        PokeBattle.socket.send('privateMessage', message.id, text)
        message.add("Me", text)
        $input.val('')

  keyUpEvent: (e) =>
    switch e.which
      when 27 # [ Esc ]
        @closePopupEvent(e)

  minimizePopupEvent: (e) =>
    message = @messageFromPopup(e.currentTarget)
    message.trigger('minimize', message)

  closePopupEvent: (e) =>
    message = @messageFromPopup(e.currentTarget)
    message.trigger('close', message)

  focusChatEvent: (e) =>
    @$closestPopup(e.currentTarget).find('input').focus()

  toggleChallengeEvent: (e) =>
    $popup = @$closestPopup(e.currentTarget)
    $challenge = $popup.find('.challenge')
    wasAtBottom = @isAtBottom($popup)
    if $challenge.hasClass("hidden")
      @createChallenge($popup)
    else if $challenge.find('.cancel_challenge').text() == 'Cancel'
      $popup.find('.send_challenge').click()
    else
      @closeChallenge(@messageFromPopup($popup))
    if wasAtBottom then @scrollToBottom($popup)

  sendChallengeEvent: (e) =>
    $popup = @$closestPopup(e.currentTarget)
    $challenge = $popup.find('.challenge')
    $challenge.find(".icon-spinner").removeClass('hidden')
    $challenge.find(".challenge_text").text('Challenging...')
    $challenge.find(".cancel_challenge").text('Cancel')

  challengeCanceledEvent: (e) =>
    message = @messageFromPopup(e.currentTarget)
    message.trigger('cancelChallenge', message.id)

  focusPopupEvent: (e) =>
    $popup = @$closestPopup(e.currentTarget)
    $popup.removeClass('new_message')
    @resetNotifications(@collection.get($popup.data('user-id')))