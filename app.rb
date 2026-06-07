# app.rb
require 'roda'

# Load architecture folders cleanly at startup
require_relative 'models/faq'
require_relative 'services/groq_service'
require_relative 'view_models/voice_chat_processor'

class App < Roda
  plugin :request_headers
  plugin :render

  # 1. Fetch credentials securely from the system profile context
  api_key = ENV['AI_API_KEY']

  if api_key.nil? || api_key.strip.empty?
    puts "❌ ERROR: No API key provided. Please set the AI_API_KEY environment variable."
    exit(1)
  end 

  puts "🚀 Launching framework dynamically linked to Groq Cloud Engine..."
  
  # 2. Instantiate interchangeable strategy client and inject into ViewModel layer
  ai_client   = GroqService.new(api_key)
  repository  = Faq.new('ntc_faq.text')
  VIEW_MODEL  = VoiceChatProcessor.new(ai_client, repository)

  # Standard language code tracking tags supported natively across telephone networks
  LANG_CODES = { 'en' => 'en-US', 'ne' => 'ne-NP' }.freeze

  route do |r|
    # Instruct the voice platform network that we are passing standard text XML data blocks
    response['Content-Type'] = 'text/xml'

    # --- JUNCTION 1: The Initial Ring Greeting Menu ---
    r.is "voice" do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Response>
          <Gather numDigits="1" action="/voice/menu" timeout="5">
            <Say voice="Polly.Joanna-Neural" language="en-US">Welcome to Nepal Telecom. For English, press 1.</Say>
            <Say voice="Polly.Madhav-Neural" language="ne-NP">नेपाल टेलिकममा स्वागत छ। नेपालीको लागि दुई थिच्नुहोस्।</Say>
          </Gather>
          <Redirect>/voice</Redirect>
        </Response>
      XML
    end

    # --- JUNCTION 2: Processing Keypad Selection ---
    r.is "voice/menu" do
      digit_pressed = r.params['Digits']
      selected_lang = (digit_pressed == '2') ? 'ne' : 'en'

      welcome_msg = (selected_lang == 'ne') ? "धन्यवाद। अब तपाईं नेपालीमा प्रश्न सोध्न सक्नुहुन्छ।" : "Thank you. You can now ask your question in English."
      voice_actor = (selected_lang == 'ne') ? "Polly.Madhav-Neural" : "Polly.Joanna-Neural"

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Response>
          <Say voice="#{voice_actor}" language="#{LANG_CODES[selected_lang]}">#{welcome_msg}</Say>
          <Gather input="speech" action="/voice/chat?lang=#{selected_lang}" speechTimeout="auto" language="#{LANG_CODES[selected_lang]}"/>
        </Response>
      XML
    end

    # --- JUNCTION 3: Continuous Intelligent Chat Interaction Loop ---
    r.is "voice/chat" do
      current_lang = r.params['lang'] || 'en'
      customer_speech = r.params['SpeechResult']

      # Query our view-model abstraction architecture layer
      reply_text = VIEW_MODEL.generate_response(customer_speech, current_lang)
      
      voice_actor   = (current_lang == 'ne') ? "Polly.Madhav-Neural" : "Polly.Joanna-Neural"
      follow_up_msg = (current_lang == 'ne') ? "के म तपाईंलाई अरू केही सहयोग गर्न सक्छु?" : "Is there anything else I can help you with?"

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Response>
          <Say voice="#{voice_actor}" language="#{LANG_CODES[current_lang]}">#{reply_text}</Say>
          <Gather input="speech" action="/voice/chat?lang=#{current_lang}" speechTimeout="auto" language="#{LANG_CODES[current_lang]}">
            <Say voice="#{voice_actor}" language="#{LANG_CODES[current_lang]}">#{follow_up_msg}</Say>
          </Gather>
        </Response>
      XML
    end

  end
end
