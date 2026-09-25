# The webpush gem (as of 1.1.0) builds EC keys by instantiating an empty
# OpenSSL::PKey::EC and mutating it afterward (generate_key!, public_key=,
# private_key=) for both the VAPID key and the per-message ECDH encryption
# key. OpenSSL 3.x's Ruby bindings made EC keys immutable after construction,
# so every one of those calls raises "pkeys are immutable on OpenSSL 3.0" —
# meaning Webpush.payload_send cannot work at all against a modern openssl
# gem without this patch. There is no newer gem release yet that fixes this,
# so the two code paths this app actually exercises (VAPID key handling, and
# payload encryption) are rebuilt here to construct EC keys immutably from
# the start instead of mutating them after creation. Verified against a real
# HTTPS round trip to Google's FCM endpoint (see PR description) — request
# signing, payload encryption, and provider response parsing all succeed.
module Webpush
  class VapidKey
    def initialize
      @curve = OpenSSL::PKey::EC.generate("prime256v1")
    end

    def self.from_keys(public_key, private_key)
      key = allocate
      key.instance_variable_set(:@curve, ec_key_from_raw(public_key, private_key))
      key
    end

    def self.ec_key_from_raw(public_key, private_key, curve_name = "prime256v1")
      group = OpenSSL::PKey::EC::Group.new(curve_name)
      public_point = OpenSSL::PKey::EC::Point.new(group, OpenSSL::BN.new(Webpush.decode64(public_key), 2))

      asn1 = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::Integer(1),
        OpenSSL::ASN1::OctetString(Webpush.decode64(private_key)),
        OpenSSL::ASN1::ASN1Data.new([ OpenSSL::ASN1::ObjectId(curve_name) ], 0, :CONTEXT_SPECIFIC),
        OpenSSL::ASN1::ASN1Data.new([ OpenSSL::ASN1::BitString(public_point.to_octet_string(:uncompressed)) ], 1, :CONTEXT_SPECIFIC)
      ])

      OpenSSL::PKey.read(asn1.to_der)
    end
  end

  module Encryption
    # Identical to the gem's implementation except the ephemeral server key
    # is built via the OpenSSL-3-compatible factory method instead of
    # EC.new(...).generate_key.
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def encrypt(message, p256dh, auth)
      assert_arguments(message, p256dh, auth)

      group_name = "prime256v1"
      salt = Random.new.bytes(16)

      server = OpenSSL::PKey::EC.generate(group_name)
      server_public_key_bn = server.public_key.to_bn

      group = OpenSSL::PKey::EC::Group.new(group_name)
      client_public_key_bn = OpenSSL::BN.new(Webpush.decode64(p256dh), 2)
      client_public_key = OpenSSL::PKey::EC::Point.new(group, client_public_key_bn)

      shared_secret = server.dh_compute_key(client_public_key)

      client_auth_token = Webpush.decode64(auth)

      info = "WebPush: info\0" + client_public_key_bn.to_s(2) + server_public_key_bn.to_s(2)
      content_encryption_key_info = "Content-Encoding: aes128gcm\0"
      nonce_info = "Content-Encoding: nonce\0"

      prk = HKDF.new(shared_secret, salt: client_auth_token, algorithm: "SHA256", info: info).next_bytes(32)
      content_encryption_key = HKDF.new(prk, salt: salt, info: content_encryption_key_info).next_bytes(16)
      nonce = HKDF.new(prk, salt: salt, info: nonce_info).next_bytes(12)

      ciphertext = encrypt_payload(message, content_encryption_key, nonce)

      serverkey16bn = convert16bit(server_public_key_bn)
      rs = ciphertext.bytesize
      raise ArgumentError, "encrypted payload is too big" if rs > 4096

      aes128gcmheader = salt.to_s + [ rs ].pack("N*") + [ serverkey16bn.bytesize ].pack("C*") + serverkey16bn

      aes128gcmheader + ciphertext
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end

# Web Push VAPID credentials. Keys are never hardcoded — generate a pair with
# `bin/rails runner 'puts Webpush.generate_key.to_h'` and set the two values
# below as environment variables (see README for the Railway variable names).
Rails.application.config.x.vapid = ActiveSupport::OrderedOptions.new.tap do |vapid|
  vapid.public_key = ENV["VAPID_PUBLIC_KEY"].presence
  vapid.private_key = ENV["VAPID_PRIVATE_KEY"].presence
  vapid.subject = ENV["VAPID_SUBJECT"].presence ||
    "mailto:#{ENV["MAILER_FROM"].presence || ENV["MAILER_SENDER"].presence || ENV["GMAIL_USERNAME"].presence || "no-reply@tokyomizochurch.org"}"

  def vapid.configured?
    public_key.present? && private_key.present?
  end
end
