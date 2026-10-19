require "net/http"
require "aws-sigv4"

# A Cloudflare R2 bucket, reached through its S3-compatible API over HTTPS.
# Railway's Hobby plan blocks outbound email (SMTP), so backups are stored
# here instead. Needs R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY
# and R2_BUCKET; R2_ENDPOINT overrides the address (e.g. an EU bucket).
class R2Bucket
  ENV_KEYS = %w[R2_ACCOUNT_ID R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_BUCKET].freeze

  class UploadError < StandardError; end

  attr_reader :bucket

  def self.configured?
    ENV_KEYS.all? { |key| ENV[key].present? }
  end

  def initialize(
    bucket: ENV.fetch("R2_BUCKET"),
    access_key_id: ENV.fetch("R2_ACCESS_KEY_ID"),
    secret_access_key: ENV.fetch("R2_SECRET_ACCESS_KEY"),
    endpoint: ENV["R2_ENDPOINT"].presence || "https://#{ENV.fetch("R2_ACCOUNT_ID")}.r2.cloudflarestorage.com"
  )
    @bucket = bucket
    @endpoint = endpoint.chomp("/")
    @signer = Aws::Sigv4::Signer.new(
      service: "s3", region: "auto",
      access_key_id: access_key_id, secret_access_key: secret_access_key
    )
  end

  def put(key, body, content_type: "application/octet-stream")
    uri = URI("#{@endpoint}/#{bucket}/#{key}")
    signature = @signer.sign_request(http_method: "PUT", url: uri.to_s, headers: { "content-type" => content_type }, body: body)

    request = Net::HTTP::Put.new(uri, signature.headers.merge("content-type" => content_type))
    request.body = body
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 60) do |http|
      http.request(request)
    end
    return key if response.is_a?(Net::HTTPSuccess)

    raise UploadError, "R2 refused #{key} (HTTP #{response.code}): #{response.body.to_s.first(200)}"
  end
end
