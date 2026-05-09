class ApplicationMailer < ActionMailer::Base
  default from: StickerSwap::RuntimeConfig.mailer_from
  layout "mailer"
end
