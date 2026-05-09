#!/bin/sh
set -eu

template_dir=/etc/nginx/sticker_swap
target=/etc/nginx/conf.d/default.conf

if [ "${NGINX_SSL_ENABLED:-false}" = "true" ]; then
  certificate_path=${NGINX_SSL_CERTIFICATE:-/etc/nginx/ssl/fullchain.pem}
  key_path=${NGINX_SSL_CERTIFICATE_KEY:-/etc/nginx/ssl/privkey.pem}

  if [ ! -f "$certificate_path" ] || [ ! -f "$key_path" ]; then
    echo "SSL is enabled but the configured certificate files were not found." >&2
    exit 1
  fi

  envsubst '$APP_DOMAIN $NGINX_SSL_CERTIFICATE $NGINX_SSL_CERTIFICATE_KEY' \
    < "$template_dir/https.conf.template" \
    > "$target"
else
  envsubst '$APP_DOMAIN' < "$template_dir/http.conf.template" > "$target"
fi

exec nginx -g 'daemon off;'