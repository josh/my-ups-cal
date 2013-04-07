webpage   = require 'webpage'
system    = require 'system'
webserver = require 'webserver'


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


# Get timezone offset.
#
# Returns hour Integer timezone offset.
getTimezoneOffset = ->
  -1 * (new Date).getTimezoneOffset() / 60

# Parse String time estimate.
#
# str - String " 2:15 PM "
#
# Returns String in UTC time.
parseTime = (str) ->
  if m = str.match /(\d\d?):(\d\d) (AM|PM)/
    hour = parseInt m[1]
    min  = parseInt m[2]
    hour += 12 if m[3] is 'PM'
    hour += getTimezoneOffset()
    "T#{padDoubleDigit(hour)}#{padDoubleDigit(min)}00Z"
  else
    ""

# Pad number to two digits.
#
# Returns String number.
padDoubleDigit = (n) ->
  if n < 10
    "0#{n}"
  else
    "#{n}"

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
  out.push "X-WR-CALNAME:UPS"
  out.push "PRODID:-//UPS My Choice//Delivery Planner//EN"
  out.push "X-APPLE-CALENDAR-COLOR:#872F04"
  out.push "X-WR-TIMEZONE:America/Chicago"
  out.push "CALSCALE:GREGORIAN"

  for row in result
    out.push "BEGIN:VEVENT"

    [month, day, year] = row[0][0].split('/')
    [start, end] = row[1][0].split('-')

    out.push "DTSTART:#{year}#{month}#{day}#{parseTime(start)}"
    out.push "DTEND:#{year}#{month}#{day}#{parseTime(end)}"

    sender = row[2][0]
    number = row[3][0]

    out.push "SUMMARY:#{sender}"
    out.push "DESCRIPTION:#{number}"
    out.push "URL:http://wwwapps.ups.com/WebTracking/processInputRequest?sort_by=status&tracknums_displayed=1&TypeOfInquiryNumber=T&loc=en_us&InquiryNumber1=#{number}&track.x=0&track.y=0"
    out.push "END:VEVENT"

  out.push "END:VCALENDAR"
  out.push ""
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

# Start web server.
#
# port - Number port
#
# Returns nothing.
startServer = (port) ->
  server = webserver.create()

  server.listen port, (request, response) ->
    if m = request.url.match(/^\/delivery.ics\?username=(\w+)&password=(\w+)$/)
      loadCalendar m[1], m[2], (err, data) ->
        if err
          response.statusCode = 500
          console.error err
        else
          response.statusCode = 200
          response.headers = 'Content-Type': "text/calendar"
          response.write data
        response.close()

    else
      response.statusCode = 401
      response.close()

# Handle main command line usuage.
#
# args - Array command line arguments
#
# Returns nothing.
main = (args) ->
  username = args[1] ? system.env['UPS_USERNAME']
  password = args[2] ? system.env['UPS_PASSWORD']

  if !username or !password
    console.error 'Usage: myups.coffee <username> <password>'
    phantom.exit()
    return

  loadCalendar username, password, (err, data) ->
    if err
      console.error err
      phantom.exit(1)
    else
      console.log data
      phantom.exit()


if port = parseInt system.args[1]
  startServer port
else
  main system.args
