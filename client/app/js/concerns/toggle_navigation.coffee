# Used to handle the show navigation button in the header, which is visible when the browser
# window becomes small enough.
$(document).ready ->
  $(".show-navigation").click =>
    $navigation = $("#navigation")
    if $navigation.hasClass('active')
      # Hide the navigation
      $navigation.animate(
        {left: -$navigation.width()}, 
        complete: -> 
          $navigation.removeClass("active")
          $navigation.css(left: 0) # Return to original position, but invisible
      )
    else
      # Show the navigation
      $navigation.addClass('active')
      $navigation.css(left: -$navigation.width())
      $navigation.animate({left: 0})