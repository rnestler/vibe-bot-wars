# frozen_string_literal: true

# Streams live arena state (broadcast by Arena::Broadcaster after every tick) to the
# browser. Read-only: commands come from bot webhooks, not from connected clients.
class ArenaChannel < ApplicationCable::Channel
  def subscribed
    stream_from Arena::Broadcaster::STREAM
  end
end
