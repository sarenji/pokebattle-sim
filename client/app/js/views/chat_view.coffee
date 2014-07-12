class @ChatView extends Backbone.View
  template: JST['chat']
  userListTemplate: JST['user_list']

  events:
    'click': 'focusChat'
    'keydown .chat_input': 'handleKeys'
    'click .chat_input_send': 'sendChat'
    'scroll_to_bottom': 'scrollToBottom'

  MAX_USERNAME_HISTORY = 10
  MAX_MESSAGES_LENGTH = 500

  # Takes a `collection`, which is a UserList instance.
  initialize: (options) =>
    {@chatEvent, @chatArgs, @noisy} = options
    @chatEvent ||= "sendChat"
    @chatArgs ||= []
    @listenTo(@collection, 'add remove reset', @renderUserList)
    if @noisy
      @listenTo(@collection, 'add', @userJoin)
      @listenTo(@collection, 'remove', @userLeave)
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
    @$('.users').html @userListTemplate(userList: @collection.models)
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
    if !PokeBattle.commands.execute(message)
      args = _.clone(@chatArgs)
      args.push(message)
      PokeBattle.primus.send(@chatEvent, args...)
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
    user = @collection.get(username)
    displayName = user?.getDisplayName() || username
    yourName = PokeBattle.username
    highlight = (new RegExp("\\b#{yourName}\\b", 'i').test(message))

    # Render the chat message
    u = "<b class='open_pm fake_link' data-user-id='#{username}'
      style='color: #{@userColor(username)}'>#{displayName}:</b>"
    @updateChat("#{@timestamp()} #{u} #{@sanitize(message)}", {highlight})

    # We might want to run something based on the message, e.g. !pbv from a mod.
    @handleMessage(user, message)

    # Record last few usernames who chatted
    index = @mostRecentNames.indexOf(username)
    @mostRecentNames.splice(index, 1)  if index != -1
    @mostRecentNames.push(username)
    @mostRecentNames.shift()  if @mostRecentNames.length > MAX_USERNAME_HISTORY

  userColor: (username) =>
    # Same hashing algorithm as in Java
    hash = 0
    for c, i in username
      chr = username.charCodeAt(i)
      hash = ((hash << 5) - hash) + chr
      hash |= 0

    h = hash % 360
    hash /= 360
    s = (hash % 25) + 75
    l = 50
    "hsl(#{h}, #{s}%, #{l}%)"

  handleMessage: (user, message) =>
    authority = user?.get('authority')
    printableCommands = ['!pbv', '!data', '/pbv', '/data']
    # TODO: no magic constants. '1' is a regular user.
    if authority > 1 && message.split(/\s/, 1)[0] in printableCommands
      PokeBattle.commands.execute(message.replace(/^\!/, '/'))

  userJoin: (user) =>
    @updateChat("#{@timestamp()} #{user.id} joined!")

  userLeave: (user) =>
    @updateChat("#{@timestamp()} #{user.id} left!")

  updateChat: (message, options = {}) =>
    wasAtBottom = @isAtBottom()
    klass = []
    klass.push('bg-blue')  if options.highlight
    klass.push(options.class)  if options.class
    @print("<p class='chat_message #{klass.join(' ')}'>#{message}</p>")
    @cleanChat()
    if wasAtBottom then @scrollToBottom()

  cleanChat: =>
    $messages = @$('.chat_message')
    numToRemove = ($messages.length - MAX_MESSAGES_LENGTH)
    if numToRemove > 0
      $messages.slice(0, numToRemove).remove()

  announce: (klass, message) =>
    wasAtBottom = @isAtBottom()
    message = @linkify(message)
    @print("<div class='alert alert-#{klass} clearfix'>#{message}</div>")
    if wasAtBottom then @scrollToBottom()

  print: (message) =>
    @$('.messages').append(message)

  clear: =>
    @$('.messages').empty()

  timestamp: =>
    date = new Date()
    hours = date.getHours()
    minutes = date.getMinutes()
    seconds = date.getSeconds()

    minutes = "00#{minutes}".substr(-2)
    seconds = "00#{seconds}".substr(-2)
    "<span class='monospace'>[#{hours}:#{minutes}:#{seconds}]</span>"

  # Escapes all HTML, but also converts links to clickable links.
  sanitize: (message) =>
    sanitizedMessage = $('<div/>').text(message).html()
    sanitizedMessage = sanitizedMessage.replace(
      /[\u0300-\u036F\u20D0-\u20FF\uFE20-\uFE2F]/g, '')
    @linkify(sanitizedMessage)

  linkify: (message) =>
    message = URI.withinString message, (url) ->
      uri = URI(url)
      [host, path] = [uri.host(), uri.path()]
      battleRegex = /^\/battles\/([a-fA-F0-9]+)$/i
      $a = $("<a/>").prop('href', url).prop('target', '_blank').text(url)

      if host == URI(window.location.href).host() && battleRegex.test(path)
        battleId = path.match(battleRegex)[1]
        $a.addClass('spectate').attr('data-battle-id', battleId)

      return $a.wrap("<div/>").parent().html()
    message

  # Returns true if the chat is scrolled to the bottom of the screen.
  # This also returns true if the messages are hidden.
  isAtBottom: =>
    $el = @$('.messages')
    ($el[0].scrollHeight - $el.scrollTop() <= $el.outerHeight())

  scrollToBottom: =>
    messages = @$('.messages')[0]
    messages.scrollTop = messages.scrollHeight
    false
