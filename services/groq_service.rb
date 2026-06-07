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
    # Direct official link to Groq's cloud endpoint
    uri = URI.parse("https://groq.com")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.keep_alive_timeout = 30
    http.max_retries = 0

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    
    # Standard header data parameters
    request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    request["Accept"] = "application/json"

    # ---- FIX: Changed model target string parameter back to Groq's official model ----
    request.body = {
      model: "llama3-8b-8192", 
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: "FAQ Context: #{context}\n\nQuestion: #{question}" }
      ],
      max_tokens: 150,
      temperature: 0.3
    }.to_json
    # ---------------------------------------------------------------------------------

    response = http.request(request)
    result = JSON.parse(response.body)
    
    # Extract response or fallback cleanly
    result.dig("choices", 0, "message", "content") || "I am sorry, my system is currently resetting."
  rescue StandardError => e
    "System Error Diagnosed: #{e.message}"
  end
end
