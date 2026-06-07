# services/base_ai_service.rb
require 'net/http'
require 'uri'
require 'json'

# SOLID: Open/Closed Principle
# Provides an architectural base configuration layer for our AI client engines.
class BaseAiService
  def initialize(api_key)
    @api_key = api_key
  end

  # Blueprint signature that child classes must implement
  def execute_chat(system_prompt, question, context)
    raise NotImplementedError, "You must implement the execute_chat method"
  end
end
