require 'date'
require 'icalendar'
require 'json'
require 'shellwords'
require 'sinatra'

module MyUpsCal
  class Server < Sinatra::Base
    include Icalendar

    SCRIPT = File.expand_path('../myups.coffee', __FILE__)

    def fetch_my_ups_data(username, password)
      return if username.nil? || password.nil?
      command = Shellwords.join(['phantomjs', SCRIPT, username, password])
      json = `#{command}`
      if $?.success?
        JSON.parse(json)
      else
        warn "phantomjs failed"
        nil
      end
    end

    def build_event_from_row(row)
      month, day, year = row[0][0].split('/')
      date = Date.new(year.to_i, month.to_i, day.to_i)

      sender = row[2][0]
      number = row[3][0]
      status = row[3][0]

      event = Event.new
      event.start = date
      event.end = date

      event.summary = sender
      event.description = "#{number}\n#{status}"

      event
    end

    def build_calendar(username, password)
      cal = Calendar.new

      if rows = fetch_my_ups_data(username, password)
        rows.each do |row|
          begin
            cal.add_event build_event_from_row(row)
          rescue Exception => e
            warn e
          end
        end
      end

      cal
    end

    get '/delivery.ics' do
      if params[:username] && params[:password]
        content_type 'text/calendar'
        build_calendar(params[:username], params[:password]).to_ical
      else
        halt 401
      end
    end
  end
end
