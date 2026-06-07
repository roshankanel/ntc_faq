require 'net/http'
require 'uri'
require 'json'

class OpenaiTtsService
  TTS_URL = 'https://api.openai.com/v1/audio/speech'.freeze
  DEFAULT_MODEL = 'gpt-4o-mini-tts'.freeze
  DEFAULT_VOICE = 'alloy'.freeze

  def initialize(api_key)
    @api_key = api_key
  end

  def synthesize(text:)
    return nil if text.to_s.strip.empty?

    uri = URI.parse(TTS_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 40

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'audio/mpeg'

    request.body = {
      model: ENV.fetch('NEPALI_TTS_MODEL', DEFAULT_MODEL),
      voice: ENV.fetch('NEPALI_TTS_PROVIDER_VOICE', DEFAULT_VOICE),
      input: text,
      response_format: 'mp3',
      instructions: 'Speak naturally in Nepali with clear pronunciation.'
    }.to_json

    response = http.request(request)
    return response.body if response.is_a?(Net::HTTPSuccess)

    nil
  rescue StandardError
    nil
  end
end
