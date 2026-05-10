namespace :inventory do
  find_user_by_email = lambda do |raw_email, task_name|
    email = raw_email.to_s.strip.downcase

    if email.empty?
      abort "Uso: bundle exec rails 'inventory:#{task_name}[user@example.com]'"
    end

    user = User.find_by(email: email)
    abort "No existe un usuario con el correo #{email.inspect}." unless user

    user
  end

  desc 'Lista las repetidas de un usuario en texto plano, ordenadas por catálogo y repitiendo cada copia'
  task :list_duplicates, [ :email ] => :environment do |_task, args|
    puts find_user_by_email.call(args[:email], 'list_duplicates').duplicate_codes_text
  end

  desc 'Lista las faltantes de un usuario en texto plano, ordenadas por catálogo'
  task :list_missing, [ :email ] => :environment do |_task, args|
    puts find_user_by_email.call(args[:email], 'list_missing').missing_codes_text
  end
end