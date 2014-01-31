class @PrivateMessagesView extends Backbone.View
  messageTemplate: JST['private_message']

  events:
    "keypress .chat_input"  : "sendMessageEvent"
    "click .challenge_button" : "challengeEvent"
    "click .popup_messages" : "focusChatEvent"
    "click .title_minimize" : "minimizePopupEvent"
    "click .title_close" : "closePopupEvent"

  initialize: =>
    @numPopups = 0
    @collection.on('open', @createPopup)
    @collection.on('receive', @receiveMessage)
    @collection.on('close minimize', @closePopup)

  createPopup: (message) =>
    title = id = message.id
    $html = @$findPopup(id)
    if @$findPopup(id).length == 0
      buttonText = "Challenge"
      $html = $(@messageTemplate({window, id, title, buttonText}))

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

  receiveMessage: (messageId, username, message, options) =>
    $popup = @$findPopup(messageId)
    $popup = @createPopup(@collection.get(messageId))  if $popup.length == 0
    $messages = $popup.find('.popup_messages')
    wasAtBottom = @isAtBottom()
    if options.type == 'error'
      $messages.append("<p class='error'>#{message}</p>")
    else
      $messages.append("<p><strong>#{username}:</strong> #{message}</p>")
    if wasAtBottom then @scrollToBottom()

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

  $closestPopup: (target) =>
    $target = $(target)
    return $target  if $target.hasClass("popup")
    return $target.closest(".popup")

  messageFromPopup: (target) =>
    $popup = @$closestPopup(target)
    message = @collection.get($popup.data('user-id'))
    return message

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
