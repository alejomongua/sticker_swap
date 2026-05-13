require 'rails_helper'

RSpec.describe 'Trading flow', type: :system do
  it 'lets a user manage inventory and send a swap offer' do
    offered_sticker = create(:sticker, prefix: 'TSU', number: 10_024, name: 'Argentina', group_name: 'Grupo J')
    requested_sticker = create(:sticker, prefix: 'TSV', number: 10_025, name: 'Brasil', group_name: 'Grupo C')
    current_user = create(:user, email: 'jugador@example.com', username: 'jugador', create_default_group: false)
    partner = create(:user, email: 'contacto@example.com', username: 'contacto', create_default_group: false)
    trading_group = create(:group, admin_user: current_user)

    trading_group.add_member!(partner)

    create(:inventory_item, :duplicate, user: partner, sticker: requested_sticker)
    create(:inventory_item, user: partner, sticker: offered_sticker, status: :missing)

    visit new_session_path
    fill_in 'Correo electrónico', with: current_user.email
    fill_in 'Contraseña', with: 'password123'
    click_button 'Ingresar'

    fill_in 'Figuras faltantes', with: requested_sticker.code
    click_button 'Guardar faltantes'

    fill_in 'Código de la figura', with: offered_sticker.code
    fill_in 'Repeticiones', with: 1
    click_button 'Agregar repetida'

    click_link 'Mercado'

    expect(page).to have_content(partner.username)
    expect(page).to have_button('Proponer trato')

    within('section', text: partner.username) do
      fill_in 'Solicitar', with: requested_sticker.code
      fill_in 'Ofrecer', with: offered_sticker.code
      click_button 'Proponer trato'
    end

    expect(page).to have_content('La propuesta se envió correctamente.')

    visit swap_offers_path
    expect(page).to have_content(partner.username)
    expect(page).to have_content('Pendiente')
  end

  it 'lets a user update repeated quantities and clear missing stickers from the dashboard' do
    duplicate_sticker = create(:sticker, prefix: 'TSW', number: 10_026, name: 'Argentina', group_name: 'Grupo J')
    missing_sticker = create(:sticker, prefix: 'TSX', number: 10_027, name: 'Brasil', group_name: 'Grupo C')
    current_user = create(:user, email: 'inventario@example.com', username: 'inventario')

    visit new_session_path
    fill_in 'Correo electrónico', with: current_user.email
    fill_in 'Contraseña', with: 'password123'
    click_button 'Ingresar'

    fill_in 'Figuras faltantes', with: missing_sticker.code
    click_button 'Guardar faltantes'

    fill_in 'Código de la figura', with: duplicate_sticker.code
    fill_in 'Repeticiones', with: 2
    click_button 'Agregar repetida'

    expect(page).to have_content('Repetidas: 2')
    expect(page).to have_content('x2')

    fill_in "Cantidad para #{duplicate_sticker.code}", with: 4
    click_button 'Actualizar'

    expect(page).to have_content('Repetidas: 4')
    expect(page).to have_content('x4')

    click_button 'Marcar conseguida'

    expect(page).to have_content('Todavía no cargaste faltantes.')
  end
end
