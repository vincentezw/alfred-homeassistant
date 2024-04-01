#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'ha'

home_assistant = HomeAssistant.new
puts home_assistant.selected_entities(ARGV.join(' '))
