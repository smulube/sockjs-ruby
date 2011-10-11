# encoding: utf-8

require "rack"
require "sockjs"
require "sockjs/adapter"

# Adapters.
require "sockjs/adapters/chunking_test"
require "sockjs/adapters/eventsource"
require "sockjs/adapters/htmlfile"
require "sockjs/adapters/iframe"
require "sockjs/adapters/jsonp"
require "sockjs/adapters/welcome_screen"
require "sockjs/adapters/xhr"

# This is a Rack middleware for SockJS.
#
# @example
#   use SockJS
#   run MyApp
module Rack
  class SockJS
    def initialize(app, prefix = "/echo")
      @app, @prefix = app, prefix
    end

    def call(env)
      matched = env["PATH_INFO"].match(/^#{Regexp.quote(@prefix)}/)

      debug "~ #{env["REQUEST_METHOD"]} #{env["PATH_INFO"].inspect} (matched: #{!! matched})"

      if matched
        ::SockJS.start do |connection, options|
          prefix  = env["PATH_INFO"].split("/")[2]
          method  = env["REQUEST_METHOD"]
          handler = ::SockJS::Adapter.handler(prefix, method)
          if handler
            debug "~ Handler: #{handler.inspect}"
            return handler.handle(env, options).tap do |response|
              debug "~ Response: #{response.inspect}"
            end
          else
            body = <<-HTML
              <!DOCTYPE html>
              <html>
                <body>
                  <h1>Handler Not Found</h1>
                  <ul>
                    <li>Prefix: #{prefix.inspect}</li>
                    <li>Method: #{method.inspect}</li>
                    <li>Handlers: #{::SockJS::Adapter.subclasses.inspect}</li>
                  </ul>
                </body>
              </html>
            HTML
            [404, {"Content-Type" => "text/html", "Content-Length" => body.bytesize.to_s}, [body]]
          end
        end
      else
        @app.call(env)
      end
    end

    private
    def debug(message)
      STDERR.puts(message)
    end
  end
end
