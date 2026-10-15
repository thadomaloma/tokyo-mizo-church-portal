require_relative "boot"

require "rails"
# Only the frameworks this app uses: no Active Storage (vouchers are
# generated pages, nothing is uploaded), Action Cable, Action Text or
# Action Mailbox. Turbo works without Action Cable.
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TokyoMizoChurchPortal
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Tokyo"

    # Shown on the Settings and sign-in pages.
    config.x.app_version = "2.0"
    config.x.app_developer = "Maloma Thado"
    # config.eager_load_paths << Rails.root.join("extras")

    # The `audited` gem YAML-serializes changed attribute values into
    # audited_changes; Psych's safe dump/load rejects any class not on this
    # list, and FinanceTransaction has a `Date` column (transaction_date).
    config.active_record.yaml_column_permitted_classes = [ Symbol, Date ]
  end
end
