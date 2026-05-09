# StickerSwap

StickerSwap es una aplicación web en Rails para que un grupo cerrado de conocidos intercambie figuritas del Mundial de forma simple. La interfaz está en español, el registro requiere código de invitación y el flujo principal gira alrededor de inventario, coincidencias y propuestas de intercambio.

## Stack

- Ruby on Rails 8.1
- Hotwire (Turbo + Stimulus)
- PostgreSQL
- Tailwind CSS vía CDN
- Autenticación nativa de Rails con recuperación de contraseña por correo
- dotenv para cargar variables locales desde `.env`
- Brevo o MailerSend como proveedores de correo transaccional
- RSpec + FactoryBot

## Funcionalidades

- Registro con código de invitación
- Inicio de sesión y recuperación de acceso por correo
- Preferencia editable para notificaciones por correo
- Carga masiva de faltantes y repetidas por código
- Mercado de coincidencias entre usuarios
- Envío, aceptación y rechazo de propuestas de intercambio
- Actualización automática del inventario al aceptar un intercambio
- Seed del catálogo completo desde `fichas.csv`

## Requisitos locales

- Ruby 4.0.3
- Bundler
- PostgreSQL o Docker

## Configuración local

Primero crea tu archivo local de variables:

```bash
cp .env.example .env
```

Luego edita `.env` con tus credenciales reales. Ese archivo está ignorado por git.

Instala dependencias:

```bash
bundle install
```

Si quieres usar la base definida en `docker-compose.yml`, levanta sólo PostgreSQL:

```bash
docker compose up -d db
```

Prepara la base local apuntando a ese contenedor:

```bash
bundle exec rails db:prepare
```

El seed crea el catálogo de figuritas. El registro usa el valor de `REGISTRATION_CODE`; es un código multiuso y seguirá siendo válido hasta que cambies esa variable.

El proveedor transaccional se controla con `EMAIL_DELIVERY_PROVIDER`.

- `file`: no envía a un proveedor externo y deja los correos en `tmp/mails` en desarrollo.
- `brevo`: usa `BREVO_API_KEY`.
- `mailersend`: usa `MAILERSEND_API_TOKEN`.

Si vas a usar SSL en Docker, deja tu certificado y tu clave privada dentro de `config/ssl`. Ese directorio está ignorado por git.

## Ejecutar la app en local

```bash
bundle exec rails server
```

La app queda disponible en la URL definida por `APP_PROTOCOL`, `APP_DOMAIN` y `APP_PORT`.

## Testing y calidad

Preparar base de test:

```bash
RAILS_ENV=test \
bundle exec rails db:prepare
```

Ejecutar specs:

```bash
RAILS_ENV=test \
bundle exec rspec
```

Ejecutar RuboCop:

```bash
bundle exec rubocop
```

## Docker Compose

El proyecto incluye estos servicios:

- `db`: PostgreSQL 16
- `web`: aplicación Rails en producción
- `nginx`: proxy reverso delante de Rails, con HTTP o HTTPS según tu `.env`

Levantar el stack completo:

```bash
docker compose up -d --build
```

Notas:

- `HTTP_PORT` publica el puerto HTTP del contenedor Nginx.
- `HTTPS_PORT` publica el puerto HTTPS del contenedor Nginx.
- La primera carga de `web` ejecuta `db:prepare`, incluyendo seeds.
- Nginx espera a que `web` responda sano en `/up` antes de exponerse.
- Si `NGINX_SSL_ENABLED=true`, Nginx exige que existan los archivos configurados en `NGINX_SSL_CERTIFICATE` y `NGINX_SSL_CERTIFICATE_KEY`.
- Las URLs generadas por Rails usan `APP_DOMAIN`, `APP_PROTOCOL` y `APP_PORT`.

En desarrollo sin SSL, la app suele quedar en `http://localhost:8080`.

Con SSL activado, la URL habitual pasa a ser `https://tu-dominio:8443` o al puerto que configures.

## Flujo recomendado de uso

1. Entra con el código de invitación inicial o crea uno adicional en consola.
2. Carga faltantes y repetidas desde el panel.
3. Ve a `Mercado` para detectar cruces.
4. Envía propuestas desde las combinaciones sugeridas.
5. Gestiona respuestas desde `Intercambios`.

## Variables principales

- `APP_DOMAIN`: dominio público o host que Rails debe usar para generar URLs.
- `APP_PROTOCOL`: `http` o `https`.
- `APP_PORT`: puerto externo que Rails debe usar al construir URLs.
- `REGISTRATION_CODE`: código de invitación multiuso vigente para nuevos registros.
- `EMAIL_DELIVERY_PROVIDER`: `file`, `brevo` o `mailersend`.
- `BREVO_API_KEY`: token de la API transaccional de Brevo.
- `MAILERSEND_API_TOKEN`: token de la API transaccional.
- `MAILER_FROM`: remitente por defecto para los correos.
- `NGINX_SSL_ENABLED`: activa la configuración HTTPS en Nginx.
- `NGINX_SSL_CERTIFICATE`: ruta del certificado dentro del contenedor Nginx.
- `NGINX_SSL_CERTIFICATE_KEY`: ruta de la clave privada dentro del contenedor Nginx.
