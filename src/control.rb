# frozen_string_literal: true

require_relative 'ha'

home_assistant = HomeAssistant.new
input = ARGV.join(' ')
entity_id, brightness = input.split(' ')

puts home_assistant.set_entity_state(entity_id, brightness)
