class @ChatView extends Backbone.View
  template: JST['chat']
  userListTemplate: JST['user_list']

  events:
    'keyup .chat_input': 'sendChatIfEnter'
    'click .chat_input_send': 'sendChat'

  # Takes a `collection`, which is a UserList instance.
  # Also takes `socket`, the socket to the server.
  initialize: (options) =>
    {@socket} = options
    @collection.on 'add remove', @renderUserList

  render: =>
    @$el.html @template()
    @renderUserList()

  renderUserList: =>
    @$('.user_count').text "Users (#{BattleTower.userList.length})"
    @$('.users').html @userListTemplate(userList: BattleTower.userList)

  sendChat: =>
    $this = $('.chat_input')
    @socket.send 'sendchat', $this.val()
    $this.val('')

  sendChatIfEnter: (e) =>
    if e.which == 13 then @sendChat()

  updateChat: (message) =>
    wasAtBottom = @isAtBottom()
    @$('.messages').append("<p>#{message}</p>")
    if wasAtBottom then @scrollToBottom()

  remove: =>
    @collection.off 'add remove', @renderUserList
    super()

  # Returns true if the chat is scrolled to the bottom of the screen.
  isAtBottom: =>
    $el = @$('.messages')
    ($el.scrollTop() + $el.innerHeight()) >= $el[0].scrollHeight

  scrollToBottom: =>
    messages = @$('.messages')[0]
    messages.scrollTop = messages.scrollHeight
