# app.rb
require 'roda'
require 'uri'

# Load local architecture modules
require_relative 'models/faq'
require_relative 'services/openai_service'
require_relative 'services/groq_service'
require_relative 'view_models/voice_chat_processor'

class App < Roda
  plugin :request_headers
  plugin :render

  api_key = ENV['AI_API_KEY']

  if api_key.nil? || api_key.strip.empty?
    puts "制造 ERROR: No API key provided. Please set the AI_API_KEY environment variable."
    exit(1)
  end 

  puts "🚀 Launching system pipeline dynamically linked to Groq Cloud Platform Engine..."
  ai_client = GroqService.new(api_key)

  repository  = Faq.new('ntc_faq.text')
  VIEW_MODEL  = VoiceChatProcessor.new(ai_client, repository)

  VOICES = { 'en' => 'Polly.Joanna-Neural', 'ne' => 'Polly.Madhav-Neural' }.freeze
  LANG_CODES = { 'en' => 'en-US', 'ne' => 'ne-NP' }.freeze

  route do |r|
    response['Content-Type'] = 'text/xml'

    # --- JUNCTION 1: The Initial Ring ---
    r.is "voice" do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Response>
          <Gather numDigits="1" action="/voice/menu" timeout="5">
            <Say voice="Polly.Joanna-Neural">Welcome to Nepal Telecom. For English, press 1.</Say>
            <Play>https://google.com</Play>
          </Gather>
          <Redirect>/voice</Redirect>
        </Response>
      XML
    end

    # --- JUNCTION 2: Processing Keypad Entry ---
    r.is "voice/menu" do
      digit_pressed = r.params['Digits']
      
      # FIX: Force strict selection criteria to catch Button 1 vs Button 2 cleanly
      selected_lang = (digit_pressed == '2') ? 'ne' : 'en'

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Response>
          #{
            if selected_lang == 'ne'
              "<Play>https://google.com</Play>"
            else
              "<Say voice=\"Polly.Joanna-Neural\">Thank you. You can now ask your question in English.</Say>"
            end
          }
          <Gather input="speech" action="/voice/chat?lang=#{selected_lang}" speechTimeout="auto" language="#{LANG_CODES[selected_lang]}"/>
        </Response>
      XML
    end

    # --- JUNCTION 3: Continuous Voice Chat ---
    r.is "voice/chat" do
      current_lang = r.params['lang'] || 'en'
      customer_speech = r.params['SpeechResult']

      # Query our decoupled view-model architecture layer
      reply_text = VIEW_MODEL.generate_response(customer_speech, current_lang)

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Response>
          #{
            if current_lang == 'ne'
              encoded_reply = URI.encode_www_form_component(reply_text)
              nepali_audio_url = "https://google.com{encoded_reply}"
              "<Play>#{nepali_audio_url}</Play>"
            else
              # FIX: Use clean text-to-speech for crisp English voice output responses
              "<Say voice=\"Polly.Joanna-Neural\">#{reply_text}</Say>"
            end
          }
          <Gather input="speech" action="/voice/chat?lang=#{current_lang}" speechTimeout="auto" language="#{LANG_CODES[current_lang]}">
            #{
              if current_lang == 'ne'
                "<Play>https://google.com</Play>"
              else
                "<Say voice=\"Polly.Joanna-Neural\">Is there anything else I can help you with?</Say>"
              end
            }
          </Gather>
        </Response>
      XML
    end

  end
end
