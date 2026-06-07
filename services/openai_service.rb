# services/openai_service.rb
require 'openai'
require_relative 'base_ai_service'

class OpenaiService < BaseAiService
  def initialize(api_key)
    super(api_key)
    @client = OpenAI::Client.new(access_token: @api_key)
  end

  def execute_chat(system_prompt, question, context)
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini", # Cheap production-tier model
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: "FAQ Context: #{context}\n\nQuestion: #{question}" }
        ],
        max_tokens: 150,
        temperature: 0.5
      }
    )
    
    response.dig("choices", 0, "message", "content")
  rescue StandardError => e
    "System Error Diagnosed: #{e.message}"
  end
end
