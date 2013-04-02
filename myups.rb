require 'date'
require 'icalendar'
require 'nokogiri'
require 'sinatra'
require 'shellwords'

module MyUpsCal
  class Server < Sinatra::Base
    include Icalendar

    SCRIPT = File.expand_path('../myups.coffee', __FILE__)

    def fetch_my_ups_html(username, password)
      return if username.nil? || password.nil?
      command = Shellwords.join(['phantomjs', SCRIPT, username, password])
      html = `#{command}`
      if $?.success?
        html
      else
        warn "phantomjs failed"
      end
    end

    def build_event_from_row(tr)
      tds = tr.css('td')

      month, day, year = tds[0].children[0].text.split('/')
      date = Date.new(year.to_i, month.to_i, day.to_i)

      sender = tds[2].children[0].text
      number = tds[3].children[0].text
      status = tds[4].children[0].text

      event = Event.new
      event.start = date
      event.end = date

      event.summary = sender
      event.description = "#{number}\n#{status}"

      event
    end

    def build_calendar(username, password)
      cal = Calendar.new

      if html = fetch_my_ups_html(username, password)
        Nokogiri::HTML(html).css('#dp_table_body > tr').each do |tr|
          begin
            cal.add_event build_event_from_row(tr)
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
