namespace :email do
  desc "Diagnostica el envío del correo de recuperación para un usuario existente"
  task :diagnose_password_reset, [ :email ] => :environment do |_task, args|
    email = args[:email].to_s.strip.downcase

    if email.empty?
      abort "Uso: bundle exec rails 'email:diagnose_password_reset[user@example.com]'"
    end

    user = User.find_by(email: email)
    abort "No existe un usuario con el correo #{email.inspect}." unless user

    provider = StickerSwap::RuntimeConfig.email_delivery_provider
    message = PasswordsMailer.reset(user)

    puts "Provider: #{provider}"
    puts "Delivery method: #{ActionMailer::Base.delivery_method}"
    puts "Brevo debug: #{StickerSwap::RuntimeConfig.brevo_debug?}"
    puts "From: #{StickerSwap::RuntimeConfig.mailer_from}"
    puts "To: #{Array(message.to).join(', ')}"
    puts "Subject: #{message.subject}"
    puts "URL config: #{StickerSwap::RuntimeConfig.default_url_options.inspect}"

    response = message.delivery_method.deliver!(message)

    if response.respond_to?(:message_id) && response.message_id.present?
      puts "Provider message_id: #{response.message_id}"
    end

    if response.respond_to?(:message_ids) && response.message_ids.present?
      puts "Provider message_ids: #{response.message_ids.inspect}"
    end

    puts "Provider response: #{response.inspect}"
  rescue StandardError => error
    warn "#{error.class}: #{error.message}"
    error.backtrace.first(10).each { |line| warn line }
    exit 1
  end
end
