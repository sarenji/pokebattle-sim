class @ChatView extends Backbone.View
  template: JST['chat']
  userListTemplate: JST['user_list']

  events:
    'click': 'focusChat'
    'keyup .chat_input': 'sendChatIfEnter'
    'click .chat_input_send': 'sendChat'
    'scroll_to_bottom': 'scrollToBottom'

  # Takes a `collection`, which is a UserList instance.
  initialize: (options) =>
    {@chatEvent, @chatArgs} = options
    @chatEvent ||= "send chat"
    @chatArgs ||= []
    @listenTo(@collection, 'add remove reset', @renderUserList)
    @listenTo(@collection, 'add', @userJoin)
    @listenTo(@collection, 'remove', @userLeave)

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

  focusChat: =>
    @$('.chat_input').focus()

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
    @updateChat("<b>#{username}:</b> #{sanitizedMessage}")

  userJoin: (user) =>
    @updateChat("#{user.id} joined!")

  userLeave: (user) =>
    @updateChat("#{user.id} left!")

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
