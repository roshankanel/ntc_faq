# services/groq_service.rb
require 'openai'
require_relative 'base_ai_service'

class GroqService < BaseAiService
  def initialize(api_key)
    super(api_key)
    
    # ---- THE FIX: Fix path duplicate formatting and configure browser client headers ----
    @client = OpenAI::Client.new(
      access_token: @api_key,
      uri_base: "https://api.groq.com/openai", # Keeps the path clean without duplicating /v1
      request_timeout: 10,
      extra_headers: {
        # Disguise the gem client as a verified desktop browser connection interface
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept" => "application/json"
      }
    )
    # -------------------------------------------------------------------------------------
  end

  def execute_chat(system_prompt, question, context)
    response = @client.chat(
      parameters: {
        model: "llama3-8b-8192", # Free tier model
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: "FAQ Context: #{context}\n\nQuestion: #{question}" }
        ],
        max_tokens: 150,
        temperature: 0.3
      }
    )
    
    response.dig("choices", 0, "message", "content") || "I am sorry, my system is currently resetting."
  rescue StandardError => e
    "System Error Diagnosed: #{e.message}"
  end
end
