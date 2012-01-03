# encoding: utf-8

require "sockjs/adapter"

module SockJS
  module Adapters
    class EventSource < Adapter
      # Settings.
      self.prefix  = /[^.]+\/([^.]+)\/eventsource$/
      self.method  = "GET"

      # Handler.
      def handle(request)
        super(request, 200) do |response, session|
          response.set_header("Content-Type", CONTENT_TYPES[:event_stream])
          response.set_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
          response.write_head

          # Opera needs to hear two more initial new lines.
          response.write("\r\n")

          self.try_timer_if_valid(request, response)
        end
      end

      def format_frame(payload)
        # Beware of leading whitespace
        ["data: ", payload, "\r\n\r\n"].join
        # ["data: ", escape_selected(payload, "\r\n\x00"), "\r\n\r\n"].join
      end

      def escape_selected(*args)
        args.join
      end
    end
  end
end
