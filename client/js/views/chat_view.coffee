class @ChatView extends Backbone.View
  template: JST['chat']
  userListTemplate: JST['user_list']

  events:
    'keyup .chat_input': 'sendChatIfEnter'
    'click .chat_input_send': 'sendChat'

  # Takes a `collection`, which is a UserList instance.
  initialize: (options) =>
    @listenTo(@collection, 'add remove reset', @renderUserList)
    @listenTo(@collection, 'add', @userJoin)
    @listenTo(@collection, 'remove', @userLeave)

  render: =>
    @$el.html @template()

  renderUserList: =>
    @$('.user_count').text "Users (#{BattleTower.userList.length})"
    @$('.users').html @userListTemplate(userList: BattleTower.userList)

  sendChat: =>
    $this = $('.chat_input')
    message = $this.val()
    @userMessage(BattleTower.username, message)
    BattleTower.socket.send('send chat', message)
    $this.val('')

  sendChatIfEnter: (e) =>
    if e.which == 13 then @sendChat()

  userMessage: (username, message) =>
    @updateChat("<b>#{username}:</b> #{message}")

  userJoin: (user) =>
    BattleTower.chatView.updateChat("#{user.id} joined BattleTower!")

  userLeave: (user) =>
    BattleTower.chatView.updateChat("#{user.id} left BattleTower!")

  updateChat: (message) =>
    @$('.messages').append("<p>#{message}</p>")

  # Returns true if the chat is scrolled to the bottom of the screen.
  isAtBottom: =>
    $el = @$('.messages')
    ($el.scrollTop() + $el.innerHeight()) >= $el[0].scrollHeight

  scrollToBottom: =>
    messages = @$('.messages')[0]
    messages.scrollTop = messages.scrollHeight
