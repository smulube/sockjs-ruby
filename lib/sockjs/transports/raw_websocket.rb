# encoding: utf-8

require "forwardable"
require "sockjs/faye"
require "sockjs/transport"

# Raw WebSocket url: /websocket
# -------------------------------
#
# SockJS protocol defines a bit of higher level framing. This is okay
# when the browser using SockJS-client establishes the connection, but
# it's not really appropriate when the connection is being established
# from another program. Although SockJS focuses on server-browser
# communication, it should be straightforward to connect to SockJS
# from command line or some any programming language.
#
# In order to make writing command-line clients easier, we define this
# `/websocket` entry point. This entry point is special and doesn't
# use any additional custom framing, no open frame, no
# heartbeats. Only raw WebSocket protocol.

module SockJS
  module Transports
    module WSDebuggingMixin
      def send_data(*args)
        if args.length == 1
          data = args.first
        else
          data = fix_buggy_input(*args)
        end

        if $DEBUG
          puts "~> WS#send #{data.inspect} #{caller[0..2].map { |item| item.sub(Dir.pwd + "/lib/", "") }.inspect}"
        else
          puts "~> WS#send #{data.inspect}"
        end

        super(data)
      end

      def fix_buggy_input(*args)
        data = 'c[3000,"Go away!"]'
        puts "! Incorrect input: #{args.inspect}, changing to #{data} for now"
        return data
      end
    end


    class RawWebSocket < Transport
      # Settings.
      self.prefix = /^websocket$/
      self.method = "GET"

      def session_class
        SockJS::Session
      end

      def check_invalid_request_or_disabled_websocket(request)
        if not @options[:websocket]
          raise HttpError.new(404, "WebSockets Are Disabled")
        elsif request.env["HTTP_UPGRADE"].to_s.downcase != "websocket"
          raise HttpError.new(400, 'Can "Upgrade" only to "WebSocket".')
        elsif not ["Upgrade", "keep-alive, Upgrade"].include?(request.env["HTTP_CONNECTION"])
          raise HttpError.new(400, '"Connection" must be "Upgrade".')
        end
      end

      # Handlers.
      def handle(request)
        check_invalid_request_or_disabled_websocket(request)

        puts "~ Upgrading to WebSockets ..."

        @ws = Faye::WebSocket.new(request.env)

        @ws.extend(WSDebuggingMixin)

        @ws.onopen do |event|
          self.handle_open(request)
        end

        @ws.onmessage = lambda do |event|
          debug "<~ WS data received: #{event.data.inspect}"
          self.handle_message(request, event)
        end

        @ws.onclose = lambda do |event|
          debug "~ Closing WebSocket connection (code: #{event.code}, reason: #{event.reason.inspect})"
          self.handle_close(request, event)
        end
      rescue SockJS::HttpError => error
        error.to_response(self, request)
      end

      # Here we need to open a new session, so we
      # can run the custom app. No opening frame.
      def handle_open(request)
      end

      # Run the app. Messages shall be send
      # without frames. This might need another
      # buffer class or another session class.
      def handle_message(request, event)
      end

      # Close the connection without sending the closing frame.
      def handle_close(request, event)
      end

      def format_frame(payload)
        raise TypeError.new("Payload must not be nil!") if payload.nil?

        payload
      end

      def send_data(frame)
        @ws.send(frame)
      end
    end
  end
end