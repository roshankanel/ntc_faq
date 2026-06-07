# view_models/voice_chat_processor.rb
require_relative '../models/faq'

class VoiceChatProcessor
  # SOLID: Dependency Injection. We pass the chosen AI engine right into the initialization process.
  def initialize(repository = Faq.new, ai_client = OpenaiService.new(ENV['AI_API_KEY']))
    @repository = repository
    @ai_client = ai_client
  end

  def generate_response(customer_speech, lang)
    if customer_speech.nil? || customer_speech.strip.empty?
      return welcome_back_prompt(lang)
    end

    faq_context = @repository.read_knowledge_base
    system_prompt = build_prompt(lang)
    
    # Run the query dynamically on whatever battery client is active!
    @ai_client.execute_chat(system_prompt, customer_speech, faq_context)
  end

  private

  def welcome_back_prompt(lang)
    lang == 'ne' ? "म सुन्दैछु, भन्नुहोस्। तपाईं नेपाल टेलिकमको बारेमा के जान्न चाहनुहुन्छ?" : "I am listening. What would you like to know about Nepal Telecom?"
  end

  def build_prompt(lang)
    if lang == 'ne'
      <<~TEXT
        You are a warm customer support agent for Nepal Telecom (NTC).
        You MUST respond strictly in the NEPALI language using Devanagari script.
        Answer the question using ONLY the provided FAQ context. Keep it under 2 sentences.
      TEXT
    else
      <<~TEXT
        You are a warm customer support agent for Nepal Telecom (NTC).
        You MUST respond strictly in the ENGLISH language.
        Answer the question using ONLY the provided FAQ context. Keep it under 2 sentences.
      TEXT
    end
  end
end
