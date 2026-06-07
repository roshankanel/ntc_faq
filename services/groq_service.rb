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
    # 📸 PRINT DEBUG NOTIFICATION RIGHT AT START
    puts "\n🔍 [DEBUG CAMERA] A curl command just arrived!"
    puts "📍 Destination URL being used: https://api.groq.com/openai/v1/chat/completions"
    puts "📝 Question asked:             #{question.inspect}\n\n"

    # 1. Establish the clean, official endpoint path link
    uri = URI.parse("https://api.groq.com/openai/v1/chat/completions")
    
    # 2. Configure our native cloud pipeline connection
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    # Crucial low-memory connection settings perfect for AWS Free Tier
    http.keep_alive_timeout = 30
    http.max_retries = 0

    # 3. Put together the network envelope request
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    
    # ---- THE CLOUDFLARE BYPASS DISGUISE ----
    request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    request["Accept"] = "application/json"
    # ----------------------------------------

    # 4. Inject our system guidelines, context text file data, and question parameters
    request.body = {
      model: "llama3-8b-8192", # Free tier model configuration
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: "FAQ Context: #{context}\n\nQuestion: #{question}" }
      ],
      max_tokens: 150,
      temperature: 0.3
    }.to_json

    # 5. Send the request and read the response
    response = http.request(request)

    # 6. Parse the JSON package response
    result = JSON.parse(response.body)
    
    # ---- 📸 THE RAW RESPONSE INSPECTION CAMERA ----
    puts "\n📦 [RAW CLOUD DATA PACKAGE RECEIVED]:"
    puts JSON.pretty_generate(result)
    puts "--------------------------------------------\n\n"

    
    # Extract response or fallback cleanly
    result.dig("choices", 0, "message", "content") || "I am sorry, my system is currently resetting."
  rescue StandardError => e
    "System Error Diagnosed: #{e.message}"
  end
end
