# services/groq_service.rb

  def execute_chat(system_prompt, question, context)
    puts "\n🔍 [DEBUG CAMERA] A curl command just arrived!"
    puts "Destination URL being used: https://groq.com"
    puts "API Key being sent:        ---------------"
    puts "📝 Question asked:             #{question.inspect}\n\n"

    response = @client.chat(
      parameters: {
        model: "llama3-8b-8192", 
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
    # ---- DIAGNOSTIC UPDATE: Capture the complete raw response payload error ----
    puts "❌ [CRITICAL ERROR DIAGNOSED]: #{e.inspect}"
    
    # Send the full detailed message straight back to your curl screen!
    "System Error Diagnosed: #{e.message}"
    # ----------------------------------------------------------------------------
  end
