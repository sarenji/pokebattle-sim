class @ChatView extends Backbone.View
  template: JST['chat']
  userListTemplate: JST['user_list']

  events:
    'keyup .chat_input': 'sendChat'

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

  sendChat: (e) =>
    if e.which == 13
      $this = $(e.target)
      @socket.emit 'sendchat', $this.val()
      $this.val('')

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
    ($el[0].scrollHeight - $el.scrollTop()) == $el.outerHeight()

  scrollToBottom: =>
    messages = @$('.messages')[0]
    messages.scrollTop = messages.scrollHeight
