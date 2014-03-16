# Used to handle the show navigation button in the header, which is visible when the browser
# window becomes small enough.
$(document).ready ->
  $navigation = $("#navigation")
  $(".show-navigation").click =>
    active = $navigation.hasClass('active')
    $navigation.toggleClass('active', !active)

  $navigation.on 'click', '.nav_item', -> $navigation.removeClass("active")