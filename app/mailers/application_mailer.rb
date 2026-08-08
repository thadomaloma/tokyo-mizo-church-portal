class ApplicationMailer < ActionMailer::Base
  default from: lambda {
    ENV["MAILER_FROM"].presence ||
      ENV["MAILER_SENDER"].presence ||
      ENV["GMAIL_USERNAME"].presence ||
      "no-reply@tokyomizochurch.org"
  }
  layout "mailer"
end
