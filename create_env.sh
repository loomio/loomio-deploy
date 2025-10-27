#!/bin/sh
set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 <hostname> <contact_email>"
  exit 1
fi

rand() {
  openssl rand -hex 32
}

POSTGRES_PASSWORD="$(rand)"
DEVISE_SECRET="$(rand)"
SECRET_COOKIE_TOKEN="$(rand)"
RAILS_INBOUND_EMAIL_PASSWORD="$(rand)"

sed -e "s|REPLACE_WITH_HOSTNAME|${1}|g" \
    -e "s|REPLACE_WITH_CONTACT_EMAIL|${2}|g" \
    -e "s|REPLACE_WITH_POSTGRES_PASSWORD|${POSTGRES_PASSWORD}|g" \
    -e "s|REPLACE_WITH_DEVISE_SECRET|${DEVISE_SECRET}|g" \
    -e "s|REPLACE_WITH_SECRET_COOKIE_TOKEN|${SECRET_COOKIE_TOKEN}|g" \
    -e "s|REPLACE_WITH_RAILS_INBOUND_EMAIL_PASSWORD|${RAILS_INBOUND_EMAIL_PASSWORD}|g" \
    env_template > .env

chmod 600 .env
echo ".env file created successfully for host: ${1}"
