source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
gem "propshaft"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "devise"
gem "prawn"
gem "prawn-table"
gem "caxlsx"
gem "caxlsx_rails"
gem "audited"
gem "pagy"
gem "dotenv-rails", groups: [ :development, :test ]

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache and Active Job
gem "solid_cache"
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
  gem "letter_opener_web"
  gem "bullet"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

gem "heroicon", "~> 1.0"

# Signs uploads of the nightly backup to Cloudflare R2 (S3-compatible API)
gem "aws-sigv4", "~> 1.12"
