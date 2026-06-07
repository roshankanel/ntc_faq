# view_models/voice_chat_processor.rb
require 'logger'
require_relative '../models/faq'

class VoiceChatProcessor
  STOP_WORDS = %w[
    a an and are as at be by for from how i in is it my of on or the to what where who why with your you can do
  ].freeze

  NEPALI_STOP_WORDS = %w[
    को का कि र मा म मेरो मेरी हामी तपाईं तिमी छ छु छन् हो के कसरी कहाँ किन कुन एउटा पनि लागि बारे बारेमा
  ].freeze

  TOKEN_ALIASES = {
    'balance' => 'balance',
    'bal' => 'balance',
    'ब्यालेन्स' => 'balance',
    'ब्यालेन्स्' => 'balance',
    'internet' => 'data',
    'data' => 'data',
    'नेट' => 'data',
    'इन्टरनेट' => 'data',
    'pack' => 'package',
    'package' => 'package',
    'प्याक' => 'package',
    'प्याकेज' => 'package',
    'offer' => 'offer',
    'offers' => 'offer',
    'रोमिङ' => 'roaming',
    'roaming' => 'roaming',
    'isd' => 'roaming',
    'volte' => 'volte',
    'hd' => 'volte',
    'फाइबर' => 'fiber',
    'fiber' => 'fiber',
    'ftth' => 'fiber',
    'adsl' => 'adsl',
    'landline' => 'landline',
    'pstn' => 'landline',
    'सिम' => 'sim',
    'sim' => 'sim',
    'puk' => 'puk',
    'pin' => 'pin',
    'waiting' => 'call_waiting',
    'forward' => 'call_forwarding',
    'forwarding' => 'call_forwarding',
    'call' => 'call'
  }.freeze

  # ---- SOLID FIX: Place the required parameter BEFORE the optional default values ----
  def initialize(ai_client, repository = Faq.new, log_file = 'chat_history.log')
    @repository = repository
    @ai_client = ai_client
    
    # Initialize our system diary stream file securely
    @logger = Logger.new(log_file)
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end
  end
  # -------------------------------------------------------------------------------------

  def generate_response(customer_speech, lang)
    if customer_speech.nil? || customer_speech.strip.empty?
      @logger.info("Call Activity | Language: #{lang.upcase} | User remained silent.")
      return welcome_back_prompt(lang)
    end

    faq_context = @repository.read_knowledge_base
    system_prompt = build_prompt(lang)

    reply_text = @ai_client.execute_chat(system_prompt, customer_speech, faq_context)

    if ai_failure?(reply_text)
      fallback_text = local_faq_fallback(customer_speech, faq_context, lang)
      @logger.warn("AI unavailable; served local fallback. Original error: #{reply_text}")
      reply_text = fallback_text
    end

    # Save the transaction metrics cleanly inside our file
    @logger.info("Voice Chat Transaction\n  -> Lang:     #{lang.upcase}\n  -> Question: \"#{customer_speech.strip}\"\n  -> Answer:   \"#{reply_text.strip}\"\n------------------------------------------------")

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
        Sound conversational and natural (use contractions like "I'll", "don't"). Keep it under 2-3 sentences.
      TEXT
    end
  end

  def ai_failure?(reply_text)
    text = reply_text.to_s.strip
    text.empty? || text.start_with?('System configuration notice:')
  end

  def local_faq_fallback(customer_speech, faq_context, lang)
    best_match = best_faq_match(customer_speech, faq_context)

    unless best_match
      return lang == 'ne' ?
        "माफ गर्नुहोस्, AI सेवा अहिले उपलब्ध छैन। कृपया छोटो रूपमा फेरि सोध्नुहोस्।" :
        "I cannot reach the AI service right now. Please rephrase your question and try again."
    end

    if lang == 'ne'
      "AI सेवा अहिले उपलब्ध छैन। FAQ अनुसार: #{best_match}"
    else
      "From our FAQ: #{best_match}"
    end
  end

  def best_faq_match(customer_speech, faq_context)
    query_tokens = tokenize(customer_speech)
    return nil if query_tokens.empty?

    faq_lines = faq_context.lines.map(&:strip).select { |line| line.start_with?('* ') }
    return nil if faq_lines.empty?

    scored = faq_lines.map do |line|
      entry = line.sub(/^\*\s+/, '')
      entry_tokens = tokenize(entry)
      overlap = (query_tokens & entry_tokens).length
      contains_phrase = query_tokens.any? { |token| entry.downcase.include?(token) } ? 1 : 0
      score = overlap * 3 + contains_phrase
      [score, entry]
    end

    best_score, best_entry = scored.max_by { |score, _entry| score }
    return nil if best_score.to_i <= 0

    best_entry[0, 260]
  end

  def tokenize(text)
    raw_tokens = text
      .to_s
      .downcase
      .scan(/[\p{L}\p{N}#*]+/u)

    normalized = raw_tokens.map { |token| TOKEN_ALIASES.fetch(token, token) }

    normalized.reject do |token|
      STOP_WORDS.include?(token) || NEPALI_STOP_WORDS.include?(token)
    end
  end
end
