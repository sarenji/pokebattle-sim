class @Replay extends Backbone.Model
  urlRoot: '/replays'

  getFormat: ->
    window.Formats[@get('format')].humanName

  getCreatedAt: ->
    date = new Date(@get('created_at'))
    day = date.getDate()
    month = date.getMonth() + 1
    year = date.getFullYear()
    timeOfDay = 'a.m.'
    hours = date.getHours()
    minutes = "00#{date.getMinutes()}"[-2...]
    seconds = "00#{date.getSeconds()}"[-2...]
    if hours > 12
      hours = hours % 12
      timeOfDay = 'p.m.'
    "#{year}/#{month}/#{day} #{hours}:#{minutes}:#{seconds} #{timeOfDay}"
