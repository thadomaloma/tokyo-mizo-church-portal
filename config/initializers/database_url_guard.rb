# Everything lives in the SQLite database configured in config/database.yml.
# Rails lets a DATABASE_URL variable override that file, and Railway adds one
# whenever a database service is linked, which would point production at an
# empty database. Refuse to boot instead, so the deploy fails, not the data.
if Rails.env.production? && ENV["DATABASE_URL"].present?
  raise "DATABASE_URL is set, but this app uses SQLite (DATABASE_PATH). " \
        "Remove DATABASE_URL from the service variables before deploying."
end
