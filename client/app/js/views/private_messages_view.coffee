class @PrivateMessagesView extends Backbone.View
  messageTemplate: JST['private_message']

  events:
    "keypress .chat_input"  : "sendMessageEvent"
    "click .challenge_button, .cancel_challenge" : "toggleChallengeEvent"
    "click .popup_messages" : "focusChatEvent"
    "click .title_minimize" : "minimizePopupEvent"
    "click .title_close" : "closePopupEvent"
    "click .accept_challenge" : "acceptChallengeEvent"
    "click .reject_challenge" : "rejectChallengeEvent"

  initialize: =>
    @numPopups = 0
    @collection.on('open', @createPopup)
    @collection.on('receive', @receiveMessage)
    @collection.on('close', @closePopup)
    @collection.on('minimize', @minimizePopup)
    @collection.on('openChallenge', @openChallenge)
    @collection.on('closeChallenge', @closeChallenge)

  createPopup: (message) =>
    title = id = message.id
    $html = @$findPopup(id)
    if @$findPopup(id).length == 0
      $html = $(@messageTemplate({window, id, title}))

      @$el.append($html)
      @positionPopup($html, @numPopups)
      @numPopups += 1
    $html.find('input').focus()
    $html

  closePopup: (message) =>
    username = message.id
    @$findPopup(username).remove()
    @repositionPopups()
    @numPopups -= 1

  minimizePopup: (message) =>
    username = message.id
    $popup = @$findPopup(username)
    $body = $popup.find('.popup_body')
    $body.toggleClass('hidden')

  receiveMessage: (messageId, username, message, options) =>
    $popup = @$findOrCreatePopup(messageId)
    $messages = $popup.find('.popup_messages')
    wasAtBottom = @isAtBottom()
    if options.type == 'error'
      $messages.append("<p class='privmsg-error'>#{message}</p>")
    else if options.type == 'alert'
      $messages.append("<p class='privmsg-alert'>#{message}</p>")
    else
      $messages.append("<p><strong>#{username}:</strong> #{message}</p>")
    if wasAtBottom then @scrollToBottom()

  openChallenge: (messageId, generation, options = {}) =>
    $popup = @$findOrCreatePopup(messageId)
    $challenge = @createChallenge($popup, generation, options)
    $challenge.find('.is_not_challenger').addClass('hidden')
    $challenge.find('.is_challenger').removeClass('hidden')

  closeChallenge: (messageId) =>
    $popup = @$findOrCreatePopup(messageId)
    $challenge = $popup.find('.challenge')
    $challenge.addClass('hidden')

  # Returns true if the chat is scrolled to the bottom of the screen.
  # This also returns true if the messages are hidden.
  isAtBottom: =>
    $el = @$('.popup_messages')
    ($el[0].scrollHeight - $el.scrollTop() <= $el.outerHeight())

  scrollToBottom: =>
    messages = @$('.popup_messages')[0]
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

  createChallenge: ($popup, generation, options = {}) =>
    $challenge = $popup.find('.challenge')
    $challenge.html(JST['challenge']())
    createChallengePane
      eventName: "challenge"
      button: $popup.find('.send_challenge')
      cancel_button: $popup.find('.cancel_challenge')
      acceptButton: $popup.find('.accept_challenge')
      rejectButton: $popup.find('.reject_challenge')
      populate: $popup.find(".challenge_data")
      generation: generation
      personId: $popup.data('user-id')
    $challenge.removeClass('hidden')
    $challenge

  ##########
  # EVENTS #
  ##########

  sendMessageEvent: (e) =>
    switch e.which
      when 13 # [ Enter ]
        $input = $(e.currentTarget)
        message = @messageFromPopup(e.currentTarget)
        text = $input.val()
        return  if text.length == 0
        PokeBattle.socket.send('privateMessage', message.id, text)
        message.add("Me", text)
        $input.val('')

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
    if $challenge.hasClass("hidden")
      @createChallenge($popup)
    else
      $challenge.addClass('hidden')
