class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Recupera tu acceso a StickerSwap", to: user.email
  end
end
