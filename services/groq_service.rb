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
    # Ensure variables are treated as flat text lines to prevent header corruption
    clean_question = question.to_s.gsub(/[^[:print:]\s]/, '').strip
    
    uri = URI.parse("https://groq.com")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.keep_alive_timeout = 30
    http.max_retries = 0

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"

    request.body = {
      model: "llama3-8b-8192", 
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: "FAQ Context: #{context}\n\nQuestion: #{clean_question}" }
      ],
      max_tokens: 150,
      temperature: 0.3
    }.to_json

    response = http.request(request)
    
    # Safety Check: If the server returns a blank body or hits an internal error, catch it
    if response.body.nil? || response.body.strip.empty? || response.body.start_with?("<!DOCTYPE html", "<html")
      return "I am sorry, the assistant network pipeline is resetting. Please ask again."
    end

    result = JSON.parse(response.body)
    
    if result["error"]
      "System configuration notice: #{result['error']['message']}"
    else
      # Extract the clean string and strip out any markdown formatting that breaks text-to-speech
      raw_content = result.dig("choices", 0, "message", "content").to_s
      raw_content.gsub(/[\*#_`\[\]()]/, '').strip
    end
  rescue StandardError => e
    "I am sorry, the system encountered an internal query issue."
  end
end
