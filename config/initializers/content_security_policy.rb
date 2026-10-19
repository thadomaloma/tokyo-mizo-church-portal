# Be sure to restart your server when you modify this file.

# Content Security Policy: the browser only runs scripts served by the app
# itself or inline scripts carrying this request's nonce, so injected
# markup cannot run code. Styles allow inline attributes (the A5 voucher and
# PWA pages use them); fonts come from Google Fonts.
# See https://guides.rubyonrails.org/security.html#content-security-policy-header
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src    :self, "https://fonts.gstatic.com"
    policy.img_src     :self, :data
    policy.connect_src :self
    policy.worker_src  :self
    policy.manifest_src :self
    policy.object_src  :none
    policy.base_uri    :self
    policy.form_action :self
    policy.frame_ancestors :none
  end

  # A fresh nonce per response for the importmap and the few inline scripts.
  # Only script-src gets it: a nonce in style-src would switch off the
  # 'unsafe-inline' that style attributes rely on.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_nonce_auto = true
end
