(function() {
  var webpage = require('webpage');
  var system = require('system');
  var webserver = require('webserver');

  // Main login url that redirects to planner page
  var loginUrl = "https://www.ups.com/one-to-one/login?loc=en_US&returnto=https://wwwapps.ups.com/mcdp?loc=en_US";

  // Invoke function when the next time the page loads.
  //
  // page - WebPage instance
  // callback - Function to invoke when finished
  //
  // Returns nothing.
  function nextLoad(page, callback) {
    return page.onLoadFinished = function(status) {
      var err;
      page.onLoadFinished = null;
      if (status !== 'success') {
        err = new Error("failed to load next page");
      }
      return callback(err);
    };
  }

  // Submit MyUPS login form.
  //
  // page     - WebPage instance
  // username - String username
  // password - String password
  // callback - Function to invoke when finished
  //
  // Returns nothing.
  function submitLogin(page, username, password, callback) {
    page.evaluate(function(username, password) {
      document.forms.LoginFacebook.uid.value = username;
      document.forms.LoginFacebook.password.value = password;
      return document.forms.LoginFacebook.next.click();
    }, username, password);
    return nextLoad(page, callback);
  }

  // Poll for calendar data to be asynchronously loaded
  //
  // page - WebPage instance
  // callback - Function to invoke when ready
  //
  // Returns nothing.
  function waitForCalendar(page, callback, retry) {
    var done, html;
    if (retry == null) {
      retry = 500;
    }
    if (retry < 0) {
      html = page.evaluate(function() {
        return document.body.innerHTML;
      });
      return callback(new Error("Timed out waiting for calendar: " + html));
    }
    done = page.evaluate(function() {
      var count, _ref, _ref1, _ref2;
      if ((_ref = document.getElementById('showTableViewId')) != null) {
        if (typeof _ref.click === "function") {
          _ref.click();
        }
      }
      if (typeof mcdp !== "undefined" && mcdp !== null) {
        if (typeof mcdp.showTableView === "function") {
          mcdp.showTableView();
        }
      }
      if (count = (_ref1 = document.getElementById('hTableNum')) != null ? _ref1.textContent : void 0) {
        if (count === "Number of Shipments: 0") {
          return true;
        } else {
          return ((_ref2 = document.getElementById('dp_table_body')) != null ? _ref2.children.length : void 0) > 0;
        }
      } else {
        return false;
      }
    });
    if (done) {
      return setTimeout(callback, 10);
    } else {
      return setTimeout(function() {
        return waitForCalendar(page, callback, retry - 1);
      }, 10);
    }
  }

  // Get timezone offset.
  //
  // Returns hour Integer timezone offset.
  function getTimezoneOffset() {
    return 5;
  }

  // Parse String time estimate.
  //
  // str - String " 2:15 PM "
  //
  // Returns String in UTC time.
  function parseTime(str) {
    var hour, m, min;
    if (m = str != null ? str.match(/(\d\d?):(\d\d) (AM|PM)/) : void 0) {
      hour = parseInt(m[1]);
      min = parseInt(m[2]);
      if (m[3] === 'PM') {
        hour += 12;
      }
      hour += getTimezoneOffset();
      return "T" + (padDoubleDigit(hour)) + (padDoubleDigit(min)) + "00Z";
    } else {
      return "";
    }
  }

  // Pad number to two digits.
  //
  // Returns String number.
  function padDoubleDigit(n) {
    if (n < 10) {
      return "0" + n;
    } else {
      return "" + n;
    }
  }

  // Build iCalendar
  //
  // page - WebPage instance
  //
  // Returns String iCalendar.
  function buildCalendar(page) {
    var day, end, month, number, out, result, row, sender, start, year, _i, _len, _ref, _ref1;
    result = page.evaluate(function() {
      var node, td, tr, _i, _len, _ref, _results;
      _ref = document.getElementById('dp_table_body').children;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        tr = _ref[_i];
        _results.push((function() {
          var _j, _len1, _ref1, _results1;
          _ref1 = tr.children;
          _results1 = [];
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            td = _ref1[_j];
            _results1.push((function() {
              var _k, _len2, _ref2, _results2;
              _ref2 = td.childNodes;
              _results2 = [];
              for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
                node = _ref2[_k];
                _results2.push(node.textContent);
              }
              return _results2;
            })());
          }
          return _results1;
        })());
      }
      return _results;
    });
    out = [];
    out.push("BEGIN:VCALENDAR");
    out.push("VERSION:2.0");
    out.push("X-WR-CALNAME:UPS");
    out.push("PRODID:-//UPS My Choice//Delivery Planner//EN");
    out.push("X-APPLE-CALENDAR-COLOR:#872F04");
    out.push("X-WR-TIMEZONE:America/Chicago");
    out.push("CALSCALE:GREGORIAN");
    for (_i = 0, _len = result.length; _i < _len; _i++) {
      row = result[_i];
      if (row[0][0] === "There are currently no shipments in transit to this home delivery address.") {
        break;
      }
      _ref = row[0][0].split('/'), month = _ref[0], day = _ref[1], year = _ref[2];
      _ref1 = row[1][0].split('-'), start = _ref1[0], end = _ref1[1];
      if (!(month && day && year)) {
        continue;
      }
      out.push("BEGIN:VEVENT");
      out.push("DTSTART:" + year + month + day + (parseTime(start)));
      out.push("DTEND:" + year + month + day + (parseTime(end)));
      sender = row[2][0];
      number = row[3][0];
      out.push("SUMMARY:" + sender);
      out.push("DESCRIPTION:" + number);
      out.push("URL:http://wwwapps.ups.com/WebTracking/processInputRequest?sort_by=status&tracknums_displayed=1&TypeOfInquiryNumber=T&loc=en_us&InquiryNumber1=" + number + "&track.x=0&track.y=0");
      out.push("END:VEVENT");
    }
    out.push("END:VCALENDAR");
    out.push("");
    return out.join("\n");
  }

  // Load calendar from MyUPS.
  //
  // username - String username
  // password - String password
  // callback - Function to invoke when finished
  //
  // Returns nothing.
  function loadCalendar(username, password, callback) {
    var page;
    page = webpage.create();
    return page.open(loginUrl, function(status) {
      if (status === 'success') {
        return submitLogin(page, username, password, function(err) {
          return waitForCalendar(page, function(err) {
            var data, e;
            if (err) {
              return callback(err);
            } else {
              try {
                data = buildCalendar(page);
              } catch (_error) {
                e = _error;
                err = e;
              }
              return callback(err, data);
            }
          });
        });
      } else {
        return callback(new Error("Failed to open " + loginUrl));
      }
    });
  }

  // Start web server.
  //
  // port - Number port
  //
  // Returns nothing.
  function startServer(port) {
    var server;
    server = webserver.create();
    return server.listen(port, function(request, response) {
      var m;
      if (m = request.url.match(/^\/delivery.ics\?username=(\w+)&password=(\w+)$/)) {
        return loadCalendar(m[1], m[2], function(err, data) {
          if (err) {
            response.statusCode = 500;
            console.error(err);
          } else {
            response.statusCode = 200;
            response.headers = {
              'Content-Type': "text/calendar",
              'Cache-Control': "public, max-age=3600"
            };
            response.write(data);
          }
          return response.close();
        });
      } else {
        response.statusCode = 401;
        return response.close();
      }
    });
  }

  // Handle main command line usuage.
  //
  // args - Array command line arguments
  //
  // Returns nothing.
  function main(args) {
    var password, username, _ref, _ref1;
    username = (_ref = args[1]) != null ? _ref : system.env['UPS_USERNAME'];
    password = (_ref1 = args[2]) != null ? _ref1 : system.env['UPS_PASSWORD'];
    if (!username || !password) {
      console.error('Usage: myups.coffee <username> <password>');
      phantom.exit();
      return;
    }
    return loadCalendar(username, password, function(err, data) {
      if (err) {
        console.error(err);
        return phantom.exit(1);
      } else {
        console.log(data);
        return phantom.exit();
      }
    });
  }

  var port;
  if (port = parseInt(system.args[1])) {
    startServer(port);
  } else {
    main(system.args);
  }

}).call(this);
