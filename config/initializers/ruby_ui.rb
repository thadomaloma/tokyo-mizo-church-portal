# frozen_string_literal: true

module RubyUI
  extend Phlex::Kit
end

# Allow using RubyUI instead RubyUi
Rails.autoloaders.main.inflector.inflect(
  "ruby_ui" => "RubyUI"
)

components_root = Rails.root.join("app/components")

# Allow using RubyUI::ComponentName instead Components::RubyUI::ComponentName
Rails.autoloaders.main.push_dir(
  components_root.join("ruby_ui"), namespace: RubyUI
)

# Allow using RubyUI::ComponentName instead RubyUI::ComponentName::ComponentName
Rails.autoloaders.main.collapse(components_root.join("ruby_ui/*"))
