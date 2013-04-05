require 'date'
require 'json'
require 'shellwords'
require 'sinatra'

module MyUpsCal
  class Server < Sinatra::Base
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
      out = []
      out << "BEGIN:VEVENT"

      month, day, year = row[0][0].split('/')
      date = Date.new(year.to_i, month.to_i, day.to_i)
      sender = row[2][0]
      number = row[3][0]

      out << "DTSTART:#{date.strftime("%Y%m%d")}"
      out << "DTEND:#{date.strftime("%Y%m%d")}"
      out << "SUMMARY:#{sender}"
      out << "DESCRIPTION:#{number}"
      out << "URL:http://wwwapps.ups.com/WebTracking/processInputRequest?sort_by=status&tracknums_displayed=1&TypeOfInquiryNumber=T&loc=en_us&InquiryNumber1=#{number}&track.x=0&track.y=0"

      out << "END:VEVENT"
      out
    end

    def build_calendar(username, password)
      out = []
      out << "BEGIN:VCALENDAR"
      out << "VERSION:2.0"
      out << "PRODID:-//UPS My Choice/Delivery Planner"

      if rows = fetch_my_ups_data(username, password)
        rows.each do |row|
          begin
            build_event_from_row(row).each do |line|
              out << line
            end
          rescue Exception => e
            warn e
          end
        end
      end

      out << "END:VCALENDAR"
      out << nil
      out
    end

    get '/delivery.ics' do
      if params[:username] && params[:password]
        content_type 'text/calendar'
        build_calendar(params[:username], params[:password]).join("\n")
      else
        halt 401
      end
    end
  end
end
