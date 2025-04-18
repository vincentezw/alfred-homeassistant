# frozen_string_literal: true

require 'net/http'
require 'json'

# HomeAssistant class to interact with Home Assistant API
class HomeAssistant
  attr_reader :base_url, :access_token

  def initialize
    @base_url = ENV['INSTANCE_URL']
    @access_token = ENV['ACCESS_TOKEN']
    @excluded_entities = ENV['EXCLUDED_ENTITIES']&.split(',') || []
    @services = %w[light switch]

    raise 'Base URL or Access Token not found in environment variables' unless @base_url && @access_token
  end

  def selected_entities(filter = nil)
    options = filter.split('%') if filter
    name_filter = options&.first
    brightness = options.last if options&.length == 2 && options.last.to_i.positive?
    selected_entities = entities.select do |entity|
      friendly_name = entity.dig('attributes', 'friendly_name')
      should_exclude = @excluded_entities.any? do |pattern|
        if pattern.include?('*')
          wildcard_match?(pattern, entity['entity_id'])
        else
          pattern == entity['entity_id']
        end
      end

      !should_exclude &&
        @services.any? { |service| entity['entity_id'].start_with?("#{service}.") } &&
        (name_filter.nil? || !friendly_name.nil? && friendly_name.downcase.include?(name_filter))
    end

    generate_json_output(selected_entities, brightness)
  end

  def set_entity_state(entity_id, brightness = nil)
    service = entity_id.split('.').first
    action = brightness.nil? ? 'toggle' : 'turn_on'
    uri = URI("#{@base_url}/api/services/#{service}/#{action}")
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@access_token}"
    request['Content-Type'] = 'application/json'
    body = { entity_id: entity_id }
    body[:brightness] = brightness if !brightness.nil? && entity_id.start_with?('light')
    request.body = body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      http.request(request)
    end

    service_type = entity_id.split('.').first
    if response.code == '200'
      "Toggled #{service_type} successfully!"
    else
      "Error toggling #{service_type}: #{response.code}"
    end
  end

  private

  def entities
    uri = URI("#{base_url}/api/states")
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"

    response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      http.request(request)
    end

    if response.code == '200'
      JSON.parse(response.body)
    else
      puts "Failed to retrieve entities. Status code: #{response.code}"
      []
    end
  end

  def generate_json_output(entities, brightness)
    {
      items: entities.map do |entity|
        entity_type = entity['entity_id'].split('.').first
        icon = "#{entity_type}-#{entity['state']}.png"
        subtitle = "switched #{entity['state']}"
        if entity_type == 'light' && entity['state'] == 'on'
          current_brightness = entity['attributes']['brightness'].to_i
          current_brightness_percent = (current_brightness / 255.0 * 100).to_i
          subtitle += ", brightness: #{current_brightness_percent}%"
        end

        {
          uid: entity['entity_id'],
          title: entity['attributes']['friendly_name'],
          subtitle: subtitle,
          arg: "#{entity['entity_id']} #{brightness}",
          icon: {
            path: "icons/#{icon}"
          }
        }
      end
    }.to_json
  end

  def wildcard_match?(pattern, string)
    regex = /\A#{Regexp.escape(pattern).gsub('\*', '.*')}\z/
    string =~ regex
  end
end
