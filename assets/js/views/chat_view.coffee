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
    @$('.user_list').html @userListTemplate(userList: BattleTower.userList)

  sendChat: (e) =>
    if e.which == 13
      $this = $(e.target)
      @socket.emit 'sendchat', $this.val()
      $this.val('')

  updateChat: (message) =>
    @$('.messages').append("<p>#{message}</p>")

  remove: =>
    @collection.off 'add remove', @renderUserList
    super()
