$ ->
  $("body").on "click", ".tab", ->
    $tab = $(this)
    $tabSection = $($tab.data("tab-for"))
    return  if $tabSection.length == 0

    # Make the correct tab active
    $tab.siblings().removeClass("active")
    $tab.addClass("active")

    # Show the correct tab section
    $tabSection.siblings().hide()
    $tabSection.show()
