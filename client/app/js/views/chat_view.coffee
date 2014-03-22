class @ChatView extends Backbone.View
  template: JST['chat']
  userListTemplate: JST['user_list']

  events:
    'click': 'focusChat'
    'keydown .chat_input': 'sendChatIfEnter'
    'click .chat_input_send': 'sendChat'
    'scroll_to_bottom': 'scrollToBottom'

  # Takes a `collection`, which is a UserList instance.
  initialize: (options) =>
    {@chatEvent, @chatArgs} = options
    @chatEvent ||= "sendChat"
    @chatArgs ||= []
    @listenTo(@collection, 'add remove reset', @renderUserList)

  # Sets the channel topic
  # TODO: Once we have rooms, create a "room" model, and make the topic
  # update by listening to the model
  setTopic: (topic) =>
    sanitizedTopic = $('<div/>').text(topic).html()
    @updateChat("<div class='alert alert-info'><b>Topic:</b> #{sanitizedTopic}</div>")

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
    $this.val('')

  sendChatIfEnter: (e) =>
    if e.which == 13 then @sendChat()

  userMessage: (username, message) =>
    sanitizedMessage = $('<div/>').text(message).html()
    sanitizedMessage = sanitizedMessage.replace(/(https?:\/\/\S+\.\S+)/g,
      """<a href="$1" target="_blank">$1</a>""")
    @updateChat("<b>#{username}:</b> #{sanitizedMessage}")

  updateChat: (message) =>
    wasAtBottom = @isAtBottom()
    @print("<p>#{message}</p>")
    if wasAtBottom then @scrollToBottom()

  print: (message) =>
    @$('.messages').append(message)

  # Returns true if the chat is scrolled to the bottom of the screen.
  # This also returns true if the messages are hidden.
  isAtBottom: =>
    $el = @$('.messages')
    ($el[0].scrollHeight - $el.scrollTop() <= $el.outerHeight())

  scrollToBottom: =>
    messages = @$('.messages')[0]
    messages.scrollTop = messages.scrollHeight
    false
