$ ->
  $('.modal').on 'shown', ->
    $(this).find('input').first().focus()

  $('#register-password-input').on 'keyup', ->
    if $(this).val().length > 0
      $('#register-confirm-password').removeClass('hidden').val('')
    else
      $('#register-confirm-password').addClass('hidden').val('')

  # Pressing submit button on the modals
  $(".modal-submit").on 'click', ->
    params = {}
    $modal = $(this).closest('.modal')
    serverEvent = $modal.data('server-event')
    $inputs = $modal.find('[data-key]')
    $passwords = $modal.find('[type="password"]')

    # Make sure the passwords match. If not, then don't submit anything.
    passwords = ($(password).val()  for password in $passwords)
    if !doPasswordsMatch(passwords)
      $passwords.next('.help-inline').text("Passwords do not match!")
      $passwords.closest('.control-group').addClass('error')
      return
    $inputs.each ->
      $input = $(this)
      key   = $input.data('key')
      value = $input.val()
      params[key] = value
    PokeBattle.socket.send(serverEvent, params)

  $('input').keypress ->
    $this = $(this)
    if $this.is(":password")
      # Find all passwords, not just this one.
      $this = $this.closest('.modal').find('[type="password"]')
    $this.closest('.control-group').removeClass('error')
    $this.next('.help-inline').text('')

$(window).load ->
  PokeBattle.socket.addEvents
    'register success' : (socket) ->
      $('.modal').modal('hide')

    'register error' : (socket, errors) ->
      errors = Array(errors)  if errors not instanceof Array
      errorText = ("<p>#{error}</p>"  for error in errors).join('')
      $('#register-modal .form-errors').html(errorText).removeClass('hidden')

    'login success' : (socket, user) ->
      $('.modal').modal('hide')
      $('.login-links').hide()
      $('.greetings').html("Greetings, <strong>#{user.id}</strong>!")
      PokeBattle.username = user.id

    'login fail' : (socket, reason) ->
      $('#login-modal .form-errors').text(reason).removeClass('hidden')

doPasswordsMatch = (passwords) ->
  return true  if passwords.length == 0
  last = passwords.pop()
  for password in passwords
    if password != last then return false
  return true
