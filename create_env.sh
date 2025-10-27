#!/bin/bash
# strips all chars except . from hostname
dots=${1//[^.]}
sed "s/REPLACE_WITH_HOSTNAME/${1}/; s/REPLACE_WITH_CONTACT_EMAIL/${2}/" scripts/default_env > .env
echo DEVISE_SECRET=`openssl rand -base64 48` >> .env
echo SECRET_COOKIE_TOKEN=`openssl rand -base64 48` >> .env
echo RAILS_INBOUND_EMAIL_PASSWORD=`openssl rand -base64 48` >> .env
