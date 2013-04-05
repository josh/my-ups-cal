require 'shellwords'
require 'sinatra'

module MyUpsCal
  class Server < Sinatra::Base
    SCRIPT = File.expand_path('../myups.coffee', __FILE__)

    get '/delivery.ics' do
      if params[:username] && params[:password]
        content_type 'text/calendar'

        command = Shellwords.join([
          'phantomjs',
          SCRIPT,
          params[:username],
          params[:password]
        ])
        data = `#{command}`
        if $?.success?
          data
        else
          warn "phantomjs failed"
          halt 500
        end
      else
        halt 401
      end
    end
  end
end
