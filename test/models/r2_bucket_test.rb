require "test_helper"

class R2BucketTest < ActiveSupport::TestCase
  include EnvHelper

  setup { @r2 = FakeR2.new }
  teardown { @r2.stop }

  test "uploads the object to the bucket with an AWS Signature V4" do
    with_env(@r2.env) do
      assert R2Bucket.configured?
      R2Bucket.new.put("tmc-backup-2030-01-02-2300.sqlite3.gz.enc", "encrypted bytes")
    end

    request = @r2.requests.sole
    assert_equal "PUT", request[:method]
    assert_equal "/tmc-backups/tmc-backup-2030-01-02-2300.sqlite3.gz.enc", request[:path]
    assert_equal "encrypted bytes", request[:body]
    assert_equal Digest::SHA256.hexdigest("encrypted bytes"), request[:headers]["x-amz-content-sha256"]
    assert_match %r{\AAWS4-HMAC-SHA256 Credential=TESTKEY/\d{8}/auto/s3/aws4_request, SignedHeaders=\S+, Signature=\h{64}\z},
                 request[:headers]["authorization"]
  end

  test "raises when R2 refuses the upload" do
    refusing = FakeR2.new(status: 403)

    with_env(refusing.env) do
      error = assert_raises(R2Bucket::UploadError) { R2Bucket.new.put("backup.enc", "bytes") }
      assert_match "HTTP 403", error.message
    end
  ensure
    refusing.stop
  end

  test "is not configured until every R2 variable is set" do
    with_env(@r2.env.merge("R2_SECRET_ACCESS_KEY" => nil)) do
      assert_not R2Bucket.configured?
    end
  end
end
