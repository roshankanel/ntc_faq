# view_models/voice_chat_processor.rb
require 'logger' # Core Ruby logging tool manager
require_relative '../models/faq_repository'

class VoiceChatProcessor
  # SOLID: Dependency Injection. The processor manages repositories, AI engines, and logs.
  def initialize(repository = FaqRepository.new, ai_client, log_file = 'chat_history.log')
    @repository = repository
    @ai_client = ai_client
    
    # Set up our secure logging stream file
    @logger = Logger.new(log_file)
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end
  end

  def generate_response(customer_speech, lang)
    if customer_speech.nil? || customer_speech.strip.empty?
      @logger.info("Call Activity | Language: #{lang.upcase} | User remained silent.")
      return welcome_back_prompt(lang)
    end

    faq_context = @repository.read_knowledge_base
    system_prompt = build_prompt(lang)
    
    # 1. Ask our strategy AI client to calculate the response string
    reply_text = @ai_client.execute_chat(system_prompt, customer_speech, faq_context)

    # 2. ---- 📝 SECURE LOG DIARY RECORDING ENTRY ----
    # Save the conversation metrics straight into our chat_history.log file
    @logger.info("Voice Chat Transaction\n  -> Lang:     #{lang.upcase}\n  -> Question: \"#{customer_speech.strip}\"\n  -> Answer:   \"#{reply_text.strip}\"\n------------------------------------------------")
    # ------------------------------------------------

    reply_text
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
        Answer the question using ONLY the provided FAQ context.
        Sound conversational and natural (use contractions like "I'll", "don't"). Keep it under 2 sentences.
      TEXT
    end
  end
end
