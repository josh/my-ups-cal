webpage = require 'webpage'
system  = require 'system'


# Main login url that redirects to planner page
loginUrl = "https://www.ups.com/one-to-one/login?loc=en_US&returnto=https://wwwapps.ups.com/mcdp?loc=en_US"

# Invoke function when the next time the page loads.
#
# page - WebPage instance
# callback - Function to invoke when finished
#
# Returns nothing.
nextLoad = (page, callback) ->
  page.onLoadFinished = (status) ->
    page.onLoadFinished = null
    err = new Error "failed to load next page" if status isnt 'success'
    callback err

# Submit MyUPS login form.
#
# page     - WebPage instance
# username - String username
# password - String password
# callback - Function to invoke when finished
#
# Returns nothing.
submitLogin = (page, username, password, callback) ->
  page.evaluate (username, password) ->
    document.forms.UserID.uid.value = username
    document.forms.UserID.password.value = password
    document.forms.UserID.next.click()
  , username, password
  nextLoad page, callback


# Poll for calendar data to be asynchronously loaded
#
# page - WebPage instance
# callback - Function to invoke when ready
#
# Returns nothing.
waitForCalendar = (page, callback, retry = 100) ->
  if retry < 0
    html = page.evaluate -> document.body.innerHTML
    return callback new Error "Timed out waiting for calendar: #{html}"

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
      waitForCalendar page, callback, retry - 1
    , 10

# Build iCalendar
#
# page - WebPage instance
#
# Returns String iCalendar.
buildCalendar = (page) ->
  result = page.evaluate ->
    for tr in document.getElementById('dp_table_body').children
      for td in tr.children
        for node in td.childNodes
          node.textContent

  out = []
  out.push "BEGIN:VCALENDAR"
  out.push "VERSION:2.0"
  out.push "PRODID:-//UPS My Choice/Delivery Planner"

  for row in result
    out.push "BEGIN:VEVENT"

    [month, day, year] = row[0][0].split('/')
    sender = row[2][0]
    number = row[3][0]

    out.push "DTSTART:#{year}#{month}#{day}"
    out.push "DTEND:#{year}#{month}#{day}"
    out.push "SUMMARY:#{sender}"
    out.push "DESCRIPTION:#{number}"
    out.push "URL:http://wwwapps.ups.com/WebTracking/processInputRequest?sort_by=status&tracknums_displayed=1&TypeOfInquiryNumber=T&loc=en_us&InquiryNumber1=#{number}&track.x=0&track.y=0"
    out.push "END:VEVENT"

  out.push "END:VCALENDAR"
  out.join "\n"

# Load calendar from MyUPS.
#
# username - String username
# password - String password
# callback - Function to invoke when finished
#
# Returns nothing.
loadCalendar = (username, password, callback) ->
  page = webpage.create()
  page.open loginUrl, (status) ->
    if status is 'success'
      submitLogin page, username, password, (err) ->
        waitForCalendar page, (err) ->
          if err then callback err
          else
            try
              data = buildCalendar page
            catch e
              err = e
            callback err, data
    else
      callback new Error "Failed to open #{loginUrl}"


username = system.args[1] ? system.env['UPS_USERNAME']
password = system.args[2] ? system.env['UPS_PASSWORD']

if !username or !password
  console.error 'Usage: myups.coffee <username> <password>'
  phantom.exit()

loadCalendar username, password, (err, data) ->
  if err
    console.error err
    phantom.exit(1)
  else
    console.log data
    phantom.exit()
