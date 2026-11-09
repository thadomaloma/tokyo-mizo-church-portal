# The commit that is running and when it was built, read from the
# BUILD_INFO file the Dockerfile writes on Railway (commit on the first
# line, UTC build time on the second). Both are nil on a local copy.
class AppBuild
  PATH = Rails.root.join("BUILD_INFO")

  attr_reader :commit, :built_at

  def self.current
    @current ||= new(PATH.exist? ? PATH.read : "", fallback_commit: ENV["RAILWAY_GIT_COMMIT_SHA"])
  end

  def initialize(text, fallback_commit: nil)
    sha, time = text.to_s.lines.map(&:strip)
    @commit = (sha.presence || fallback_commit.presence)&.first(7)
    @built_at = begin
      Time.iso8601(time.to_s).in_time_zone
    rescue ArgumentError
      nil
    end
  end
end
