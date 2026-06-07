# services/groq_service.rb
require 'net/http'
require 'uri'
require 'json'
require_relative 'base_ai_service'

class GroqService < BaseAiService
  def initialize(api_key)
    super(api_key)
  end

  def execute_chat(system_prompt, question, context)
    uri = URI.parse("https://groq.com")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    # Standard server-to-server optimization parameters
    http.keep_alive_timeout = 30
    http.max_retries = 0

    # ---- FIX: Use clean standard API headers without any fake browser masks ----
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    # -----------------------------------------------------------------------------

    request.body = {
      model: "llama3-8b-8192", 
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: "FAQ Context: #{context}\n\nQuestion: #{question}" }
      ],
      max_tokens: 150,
      temperature: 0.3
    }.to_json

    response = http.request(request)
    
    # Safety Check: If the server returns nothing or crashes, catch it before parsing
    if response.body.nil? || response.body.strip.empty?
      return "I am sorry, the network channel dropped. Please try again."
    end

    result = JSON.parse(response.body)
    
    # Extract the beautiful text response or handle validation faults
    if result["error"]
      "System Error: #{result['error']['message']}"
    else
      result.dig("choices", 0, "message", "content") || "I am sorry, my system is currently resetting."
    end
  rescue StandardError => e
    "System Error Diagnosed: #{e.message}"
  end
end
