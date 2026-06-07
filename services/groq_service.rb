# services/groq_service.rb
require 'net/http'
require 'uri'
require 'json'
require_relative 'base_ai_service'

class GroqService < BaseAiService
  DEFAULT_MODEL = 'llama-3.1-8b-instant'.freeze
  CHAT_URL = 'https://api.groq.com/openai/v1/chat/completions'.freeze

  def initialize(api_key)
    super(api_key)
  end

  def execute_chat(system_prompt, question, context)
    # Safely format the question into a standard text line without using rough regex sponges
    clean_question = question.to_s.strip
    
    uri = URI.parse(CHAT_URL)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.keep_alive_timeout = 30
    http.max_retries = 0
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"

    request.body = {
      model: ENV['GROQ_MODEL'] || DEFAULT_MODEL,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: "FAQ Context: #{context}\n\nQuestion: #{clean_question}" }
      ],
      max_tokens: 150,
      temperature: 0.3
    }.to_json

    response = http.request(request)
    body = response.body.to_s

    if body.strip.empty?
      return "System configuration notice: AI service returned an empty response."
    end

    content_type = response['content-type'].to_s.downcase
    parsed = nil

    if content_type.include?('application/json')
      begin
        parsed = JSON.parse(body)
      rescue JSON::ParserError
        return "System configuration notice: AI service returned malformed JSON (HTTP #{response.code})."
      end
    elsif body.lstrip.start_with?('<!doctype html', '<html')
      return "System configuration notice: AI endpoint returned HTML (HTTP #{response.code}). Check endpoint or key."
    end

    if !response.is_a?(Net::HTTPSuccess)
      error_message = if parsed && parsed['error'].is_a?(Hash)
                        parsed['error']['message']
                      else
                        body[0, 220]
                      end
      return "System configuration notice: HTTP #{response.code} - #{error_message}"
    end

    if parsed.nil?
      begin
        parsed = JSON.parse(body)
      rescue JSON::ParserError
        return "System configuration notice: AI service did not return valid JSON."
      end
    end

    if parsed['error']
      return "System configuration notice: #{parsed.dig('error', 'message')}"
    end

    raw_content = parsed.dig('choices', 0, 'message', 'content').to_s.strip
    if raw_content.empty?
      return "System configuration notice: AI response had no answer text."
    end

    # Remove markdown punctuation that can sound odd in TTS.
    raw_content.gsub(/[\*#_`\[\]()]/, '')
  rescue Net::OpenTimeout, Net::ReadTimeout
    "System configuration notice: AI request timed out. Please try again."
  rescue StandardError => e
    "System configuration notice: Unexpected AI client error - #{e.class}."
  end
end
