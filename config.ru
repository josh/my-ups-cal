ENV['PATH'] = "/app/vendor/phantomjs/bin:#{ENV['PATH']}"
ENV['LD_LIBRARY_PATH'] = "/app/vendor/phantomjs/lib:#{ENV['LD_LIBRARY_PATH']}"

require File.expand_path('../myups', __FILE__)
run MyUpsCal::Server
