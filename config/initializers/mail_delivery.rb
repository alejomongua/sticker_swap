require Rails.root.join("lib/mailersend_delivery_method")

ActionMailer::Base.add_delivery_method(
  :mailersend,
  MailersendDeliveryMethod
)
