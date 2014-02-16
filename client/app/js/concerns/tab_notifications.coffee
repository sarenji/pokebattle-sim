DEFAULT_INTERVAL = 1000
original  = document.title
timeoutId = undefined

$.flashTitle = (newMsg, interval) ->
  if newMsg == false
    # stop flashing and reset title
    clearTimeout(timeoutId)
    document.title = original
  else
    # loop flashing
    interval = interval || DEFAULT_INTERVAL
    timeoutId = setTimeout( ->
      clearTimeout(timeoutId)
      document.title = if (document.title == original) then newMsg else original
      timeoutId = setTimeout(arguments.callee, interval)
    , interval)


PokeBattle.NotificationTypes =
  PRIVATE_MESSAGE:
    showDesktop: false
  BATTLE_STARTED:
    showDesktop: true
    prefix: "bs"
    title: "Battle Started"
    body: "Your battle has started!"
  ACTION_REQUESTED:
    showDesktop: true
    prefix: "ar"
    title: "Battle Action Requested"
    body: "A battle is ready for your input!"

notifications = []

# Currently called in concerns/find_battle.coffee
PokeBattle.requestNotifyPermission = =>
  if notify.permissionLevel() == notify.PERMISSION_DEFAULT
    notify.requestPermission()
    
# TODO: Count the notifications by unique type/identifier combos
PokeBattle.notifyUser = (type, identifier) =>
  return  if document.hasFocus()
  $.flashTitle "You have new notification(s)"

  if type.showDesktop
    notification = notify.createNotification type.title,
      icon: "/images/logo/pb_red.png"
      body: type.body
      tag: "PokeBattle_#{type.prefix}_#{identifier}"

    notifications.push notification

$(window).focus ->
  $.flashTitle(false)
  notification.close()  for notification in notifications
  notifications = []
  