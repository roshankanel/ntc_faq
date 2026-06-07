# app.rb
require 'roda'

# Load our local clean architecture components
require_relative 'models/faq'
require_relative 'services/openai_service'
require_relative 'services/groq_service'
require_relative 'view_models/voice_chat_processor'

class App < Roda
  plugin :request_headers
  plugin :render

  # 1. Load up our dynamic environment settings
  provider_choice = ENV.fetch('AI_PROVIDER', 'openai').downcase
  api_key         = ENV['AI_API_KEY']

  unless api_key.nil? || api_key.strip.empty?
    puts "Using #{provider_choice.capitalize} as AI provider with provided API key."
  else
    puts "No API key provided. Please set the AI_API_KEY environment variable."
    exit(1)
  end
  # 2. Build our interchangeable AI client strategy block
  ai_client = (provider_choice == 'groq') ? GroqService.new(api_key) : OpenaiService.new(api_key)

  puts "provider_choice: #{provider_choice}"
    puts "provider_choice: #{provider_choice} #{provider_choice == 'groq'}"
  puts provider_choice == 'groq' ? "GroqService initialized successfully." : "OpenaiService initialized successfully."  
  puts "AI Client initialized: #{ai_client.class.name}"

  # 3. Inject dependencies into our custom processor layout
  repository  = Faq.new('ntc_faq.text')
  VIEW_MODEL  = VoiceChatProcessor.new(repository, ai_client)

  VOICES = { 'en' => 'Polly.Joanna-Neural', 'ne' => 'ne-NP-SagarNeural' }.freeze
  LANG_CODES = { 'en' => 'en-US', 'ne' => 'ne-NP' }.freeze

  route do |r|
    # Tell the phone network we are passing flat text XML data structures
    response['Content-Type'] = 'text/xml'

    # --- JUNCTION 1: The Initial Ring ---
    r.is "voice" do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Response>
          <Gather numDigits="1" action="/voice/menu" timeout="5">
            <Say voice="Polly.Joanna-Neural">Welcome to Nepal Telecom. For English, press 1.</Say>
            <Say voice="ne-NP-SagarNeural">नेपाल टेलिकममा स्वागत छ। नेपालीको लागि दुई थिच्नुहोस्।</Say>
          </Gather>
          <Redirect>/voice</Redirect>
        </Response>
      XML
    end

    # --- JUNCTION 2: Reading Keypad Entry ---
    r.is "voice/menu" do
      digit_pressed = r.params['Digits']
      selected_lang = (digit_pressed == '2') ? 'ne' : 'en'

      welcome_msg = if selected_lang == 'ne'
        "धन्यवाद। अब तपाईं नेपालीमा प्रश्न सोध्न सक्नुहुन्छ।"
      else
        "Thank you. You can now ask your question in English."
      end

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Response>
          <Say voice="#{VOICES[selected_lang]}">#{welcome_msg}</Say>
          <Gather input="speech" action="/voice/chat?lang=#{selected_lang}" speechTimeout="auto" language="#{LANG_CODES[selected_lang]}"/>
        </Response>
      XML
    end

    # --- JUNCTION 3: The Dynamic AI Loop ---
    r.is "voice/chat" do
      current_lang = r.params['lang'] || 'en'
      customer_speech = r.params['SpeechResult']

      # Query our ViewModel directly without any external network wrappers wrapping this step!
      reply_text = VIEW_MODEL.generate_response(customer_speech, current_lang)

      follow_up_msg = (current_lang == 'ne') ? "के म तपाईंलाई अरू केही सहयोग गर्न सक्छु?" : "Is there anything else I can help you with?"

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Response>
          <Say voice="#{VOICES[current_lang]}">#{reply_text}</Say>
          <Gather input="speech" action="/voice/chat?lang=#{current_lang}" speechTimeout="auto" language="#{LANG_CODES[current_lang]}">
            <Say voice="#{VOICES[current_lang]}">#{follow_up_msg}</Say>
          </Gather>
        </Response>
      XML
    end

  end
end
