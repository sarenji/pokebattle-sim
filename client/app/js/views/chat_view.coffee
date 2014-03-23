class @ChatView extends Backbone.View
  template: JST['chat']
  userListTemplate: JST['user_list']

  events:
    'click': 'focusChat'
    'keydown .chat_input': 'handleKeys'
    'click .chat_input_send': 'sendChat'
    'scroll_to_bottom': 'scrollToBottom'

  MAX_USERNAME_HISTORY = 10

  # Takes a `collection`, which is a UserList instance.
  initialize: (options) =>
    {@chatEvent, @chatArgs} = options
    @chatEvent ||= "sendChat"
    @chatArgs ||= []
    @listenTo(@collection, 'add remove reset', @renderUserList)
    @chatHistory = []
    @mostRecentNames = []
    @tabCompleteIndex = -1
    @tabCompleteNames = []

  # Sets the channel topic
  # TODO: Once we have rooms, create a "room" model, and make the topic
  # update by listening to the model
  setTopic: (topic) =>
    topic = @sanitize(topic)
    @updateChat("<div class='alert alert-info'><b>Topic:</b> #{topic}</div>")

  render: =>
    @$el.html @template()
    this

  renderUserList: =>
    @$('.user_count').text "Users (#{@collection.length})"
    @$('.users').html @userListTemplate(userList: @collection)
    this

  getSelectedText: =>
    text = ""
    if window.getSelection
      text = window.getSelection().toString()
    else if document.selection && document.selection.type != "Control"
      text = document.selection.createRange().text
    return text

  focusChat: =>
    selectedText = @getSelectedText()
    @$('.chat_input').focus()  if selectedText.length == 0

  sendChat: =>
    $this = @$('.chat_input')
    message = $this.val()
    return  unless message?.replace(/\s+$/).length > 0
    args = _.clone(@chatArgs)
    args.push(message)
    if !PokeBattle.commands.execute(message)
      PokeBattle.socket.send(@chatEvent, args...)
    @chatHistory.push(message)
    delete @chatHistoryIndex
    $this.val('')

  tabComplete: ($input, options = {}) =>
    cursorIndex = $input.prop('selectionStart')
    text = $input.val()
    if @tabCompleteNames.length > 0 && @tabCompleteCursorIndex == cursorIndex
      if options.reverse
        @tabCompleteIndex -= 1
        if @tabCompleteIndex < 0
          @tabCompleteIndex = @tabCompleteNames.length - 1
      else
        @tabCompleteIndex = (@tabCompleteIndex + 1) % @tabCompleteNames.length
    else
      delete @tabCompleteCursorIndex
      pieces = text[0...cursorIndex].split(' ')
      possibleName = pieces.pop()
      rest = pieces.join(' ')
      rest += ' '  if pieces.length > 0  # Append a space if a word exists
      length = possibleName.length
      return  if length == 0
      candidates = _.union(@mostRecentNames, @collection.pluck('id'))
      candidates = candidates.filter (name) ->
        name[...length].toLowerCase() == possibleName.toLowerCase()
      return  if candidates.length == 0
      if options.reverse
        @tabCompleteIndex = candidates.length - 1
      else
        @tabCompleteIndex = 0
      @tabCompleteNames = candidates
      @tabCompletePrefix = rest
      @tabCompleteCursorIndex = cursorIndex
    tabbedName = @tabCompleteNames[@tabCompleteIndex]
    newPrefix = @tabCompletePrefix + tabbedName
    newPrefixLength = newPrefix.length
    $input.val(newPrefix + text[cursorIndex...])
    $input[0].setSelectionRange(newPrefixLength, newPrefixLength)
    @tabCompleteCursorIndex = newPrefixLength

  handleKeys: (e) =>
    $input = $(e.currentTarget)
    switch e.which
      when 13  # [Enter]
        e.preventDefault()
        @sendChat()
      when 9   # [Tab]
        e.preventDefault()
        @tabComplete($input, reverse: e.shiftKey)
      when 38  # [Up arrow]
        e.preventDefault()
        return  if @chatHistory.length == 0
        if !@chatHistoryIndex?
          @chatHistoryIndex = @chatHistory.length
          @chatHistoryText = $input.val()
        if @chatHistoryIndex > 0
          @chatHistoryIndex -= 1
          $input.val(@chatHistory[@chatHistoryIndex])
      when 40  # [Down arrow]
        e.preventDefault()
        return  unless @chatHistoryIndex?
        @chatHistoryIndex += 1
        if @chatHistoryIndex == @chatHistory.length
          $input.val(@chatHistoryText)
          delete @chatHistoryIndex
        else
          $input.val(@chatHistory[@chatHistoryIndex])

  userMessage: (username, message) =>
    @updateChat("<b>#{username}:</b> #{@sanitize(message)}")

    # Record last few usernames who chatted
    @mostRecentNames.push(username)  if username not in @mostRecentNames
    @mostRecentNames.shift()  if @mostRecentNames.length > MAX_USERNAME_HISTORY

  updateChat: (message) =>
    wasAtBottom = @isAtBottom()
    @print("<p>#{message}</p>")
    if wasAtBottom then @scrollToBottom()

  print: (message) =>
    @$('.messages').append(message)

  # Escapes all HTML, but also converts links to clickable links.
  sanitize: (message) =>
    sanitizedMessage = $('<div/>').text(message).html()
    sanitizedMessage = sanitizedMessage.replace(
      /\b(https?:\/\/\S+\.\S+)\b/g,
      """<a href="$1" target="_blank">$1</a>""")
    sanitizedMessage

  # Returns true if the chat is scrolled to the bottom of the screen.
  # This also returns true if the messages are hidden.
  isAtBottom: =>
    $el = @$('.messages')
    ($el[0].scrollHeight - $el.scrollTop() <= $el.outerHeight())

  scrollToBottom: =>
    messages = @$('.messages')[0]
    messages.scrollTop = messages.scrollHeight
    false
