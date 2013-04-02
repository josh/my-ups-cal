webpage = require 'webpage'
system  = require 'system'


if system.args.length isnt 3
  console.error 'Usage: myups.coffee <username> <password>'
  phantom.exit()


# Timeout after 10secs
setTimeout ->
  phantom.exit 1
, 10000


page = webpage.create()

nextLoad = (callback) ->
  page.onLoadFinished = ->
    page.onLoadFinished = null
    callback()

waitForCalendar = (callback) ->
  el = page.evaluate ->
    document.getElementById('calendar')? and
      document.getElementById('dp_table_body')?

  if el
    setTimeout callback, 500
  else
    setTimeout ->
      waitForCalendar callback
    , 100

submitLogin = (callback) ->
  page.evaluate (username, password) ->
    document.forms.UserID.uid.value = username
    document.forms.UserID.password.value = password
    document.forms.UserID.next.click()
  , system.args[1], system.args[2]
  nextLoad callback


page.open "https://www.ups.com/one-to-one/login?loc=en_US&returnto=https://wwwapps.ups.com/mcdp?loc=en_US", ->
  submitLogin ->
    waitForCalendar ->
      html = page.evaluate -> document.documentElement.innerHTML
      console.log html
      phantom.exit()
