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
  count = page.evaluate ->
    document.getElementById('hTableNum').innerHTML

  done = page.evaluate ->
    if count = document.getElementById('hTableNum')?.textContent
      if count is "Number of Shipments: 0"
        true
      else
        document.getElementById('dp_table_body')?.children.length > 0
    else
      false


  if done
    setTimeout callback, 10
  else
    setTimeout ->
      waitForCalendar callback
    , 10

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
      result = page.evaluate ->
        for tr in document.getElementById('dp_table_body').children
          for td in tr.children
            for node in td.childNodes
              node.textContent

      console.log JSON.stringify(result)
      phantom.exit()
