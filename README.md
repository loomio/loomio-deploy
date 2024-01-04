# Deploy your own Loomio

This is what you need to run your own Loomio server.

It will run all Loomio services on a single host via docker and docker compose, complete with an SSL certificate via letsencrypt.

If you just want a local install of Loomio for development, see [Setting up a Loomio development environment](https://github.com/loomio/loomio/blob/master/DEVSETUP.md).

## What you'll need
* Root access to a server, on a public IP address, running Ubuntu with at least 1GB RAM (2GB recommended).

* A domain name

* An SMTP server

## Network configuration
For this example, the hostname will be loomio.example.com and the IP address is 123.123.123.123

### DNS Records
To allow people to access the site via your hostname you need an A record:

```
A loomio.example.com, 123.123.123.123
```

Loomio supports "Reply by email" and to enable this you need an MX record so mail servers know where to direct these emails.

```
MX loomio.example.com, loomio.example.com, priority 0
```

Additionally, create a CNAME record that points `channels.loomio.example.com` to `loomio.example.com`.

```
CNAME channels.loomio.example.com, loomio.example.com
```

## Configure the server

### Login as root
To login to the server, open a terminal window and type:

```sh
ssh -A root@loomio.example.com
```

### Install docker

These steps to install docker are copied from [docs.docker.com](https://docs.docker.com/engine/install/ubuntu/)

```sh
apt-get update
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Clone the loomio-deploy git repository
This is the place where all the configuration for your Loomio services will live. In this step you make a copy of this repo, so that you can modify the settings to work for your particular setup.

As root on your server, clone this repo:

```sh
git clone https://github.com/loomio/loomio-deploy.git
cd loomio-deploy
```

The commands below assume your working directory is this repo, on your server.

### Setup a swapfile (optional)
There are some simple scripts within this repo to help you configure your server.

This script will create and mount a 4GB swapfile. If you have less than 2GB RAM on your server then this step is required.

```sh
./scripts/create_swapfile
```

### SSL teriminating proxy

By default, docker-compose.yml includes an nginx proxy container that automatically handles fetching an SSL certificate via LetsEncrypt.org. If you don't need SSL termination, or you're running Loomio from behind a proxy, you can safely remove the nginx services from the docker-compose.yml file. The loomio app container will happily speak plain HTTP on port 3000 (by default). Configuring reverse proxies and other advanced configurations are outside the scope of this documentation, but at minimum it's suggested to preserve the HTTP host header and to set X-FORWARDED-PROTO if terminating SSL upstream.

### Create your ENV files
This script creates `env` files configured for you. It also creates directories on the host to hold user data.

When you run this, remember to change `loomio.example.com` to your hostname, and give your contact email address, so you can recover your SSL keys later if required.

```sh
./scripts/create_env loomio.example.com you@contact.email
```

Now have a look inside the files:

```sh
cat .env
```

### OAuth2 and OIDC (optional)

The default environment file isn't configured for OAuth2 authentication out of the box. In order to enable it, there are several environment variables that need to be set to appropriate values:

- `OAUTH_AUTH_URL` is used to specify the auth endpoint, for example `https://sso.yourdomain.com/realms/YourRealm/protocol/openid-connect/auth`.
- `OAUTH_TOKEN_URL` is used to specify the token endpoint, for example `https://sso.yourdomain.com/realms/YourRealm/protocol/openid-connect/token`.
- `OAUTH_PROFILE_URL` is used to fetch the user's profile data, for example `https://sso.yourdomain.com/realms/YourRealm/protocol/openid-connect/userinfo`.
- `OAUTH_SCOPE` is the list of scopes passed in the auth request, for example `openid email profile`.
- `OAUTH_APP_KEY` is what OIDC refers to as the Client ID. For example, `loomio`.
- `OAUTH_APP_SECRET` is what OIDC refers to as the Client Secret. It's a long string of letters and numbers and other characters.
- `OAUTH_ATTR_UID` specifies which user profile field is used for Loomio's internal unique identifier for this user. For example, `email`.
- `OAUTH_ATTR_NAME` specifies which user profile field is used for Loomio's displayed name, for example `name`.
- `OAUTH_ATTR_EMAIL` specifies which user profile field is used for the Loomio account email address, for example `email`.
- `OAUTH_LOGIN_PROVIDER_NAME` is the label used for the SSO login button. The user will see this value when they're prompted to log in using SSO. For example, `Your Domain SSO`.

For the ATTR variables, if you're not sure what your OAuth provider is returning, you can attempt a login and check the Loomio logs to see the response.

If you do not wish to allow users to create non-SSO accounts, you should also use `FEATURES_DISABLE_EMAIL_LOGIN=1` to disable non-SSO logins.

### SAML (optional)

The default environment file isn't configured for SAML authentication out of the box. In order to enable it, there are several environment variables that need to be set to appropriate values:

- `SAML_IDP_METADATA_URL` is used to specify the metadata endpoint, for example `https://sso.yourdomain.com/realms/YourRealm/protocol/saml/descriptor`. This setting is ignored if `SAML_IDP_METADATA` is set.
- `SAML_IDP_METADATA` is used to directly specify the SAML configuration rather than fetching it from a URL. Useful if you don't want to hammer your SAML provider for this data, but not recommended for general use.
- `SAML_ISSUER` is occasionally useful if you need to override the issuer value.
- `SAML_LOGIN_PROVIDER_NAME` is the label used for the SSO login button. The user will see this value when they're prompted to log in using SSO. For example, `Your Domain SSO`.

Attribute mapping is not supported for SAML.

If you do not wish to allow users to create non-SSO accounts, you should also use `FEATURES_DISABLE_EMAIL_LOGIN=1` to disable non-SSO logins.

### Setup SMTP

You need to bring your own SMTP server for Loomio to send emails.

If you already have an SMTP server, that's great, put the settings into the `env` file.

For everyone else here are some options to consider:

- Look at the (sometimes free) services offered by [SendGrid](https://sendgrid.com/), [SparkPost](https://www.sparkpost.com/), [Mailgun](http://www.mailgun.com/), [Mailjet](https://www.mailjet.com/pricing).

- Setup your own SMTP server with something like Haraka

Edit the `.env` file and enter the right SMTP settings for your setup.

You might also need to add an SPF DNS record to indicate that the SMTP can send mail for your domain.

### Initialize the database
This command initializes a new database for your Loomio instance to use.

```
docker compose up -d db
docker compose run app rake db:setup
```

### Install crontab
Doing this tells the server what regular tasks it needs to run. These tasks include:

* Noticing which proposals are closing in 24 hours and notifying users.
* Closing proposals and notifying users they have closed.
* Sending "Yesterday on Loomio", a digest of activity users have not already read. This is sent to users at 6am in their local timezone.

Run `crontab -e` and append the following line:

```
0 * * * *  /usr/bin/docker exec loomio-worker bundle exec rake loomio:hourly_tasks > ~/rake.log 2>&1
```

## Starting the services
This command starts the database, application, reply-by-email, and live-update services all at once.

```
docker compose up -d
```

Give it a minute to start, then visit your URL while crossing your fingers!

If you visit the url with your browser and the rails server is not yet running, but nginx is, you'll see a "503 bad gateway" error message.

You'll want to see the logs as it all starts, run the following command:

```
docker compose logs -f
```

## Try it out

visit your hostname in your browser.

Once you have signed in (and confirmed your email), grant yourself admin rights

```
docker compose run app rails c
User.last.update(is_admin: true)
```

you can now access the admin interface at https://loomio.example.com/admin


## If something goes wrong

To see system error messages as they happen run `docker compose logs -f` and make a request against the server.

If you want to be notified of system errors you could setup [Sentry](https://sentry.io/) and add it to the env.

Confirm `env` settings are correct.

After you change your `env` files you need to restart the system:

```sh
docker compose down
docker compose up -d
```

To update Loomio to the latest stable version just run the update script.

```sh
./scripts/update
```

To login to your running rails app console:

```sh
docker compose run app rails c
```

A PostgreSQL shell to inspect the database:

```sh
docker exec -ti loomio-db su - postgres -c 'psql loomio_production'
```

## Backups

The default docker-compose.yml includes automatic backups with [prodrigestivill/docker-postgres-backup-local](https://github.com/prodrigestivill/docker-postgres-backup-local), however, you'll need to run `mkdir -p pgdumps && chown -R 999:999 pgdumps` to set the correct permissions for this to work.

You can test that the automatic backup permissions are correct with this command:

```
docker run --rm -v "$PWD:/backups" -u "$(id -u):$(id -g)" --network=loomio-deploy_main -e POSTGRES_HOST=db -e POSTGRES_DB=loomio_production -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=password  prodrigestivill/postgres-backup-local /backup.sh
```

However, sometimes you just want to make or restore an SQL snapshot directly.

Dump SQL
```
docker exec -ti loomio-db su - postgres -c 'pg_dump -c loomio_production' > loomio_production.sql
```

Restore SQL
```
cat loomio_production.sql | docker exec -i loomio-db su - postgres -c 'psql loomio_production'
```

# Updating old versions of Loomio

Please upgrade through the following versions. You need to edit `.env` and change LOOMIO_CONTAINER_TAG to each version, then run `./scripts/update`. When the migrations have completed, apply the next tag and repeat. 

- v2.4.2
- v2.8.8
- v2.11.13
- v2.15.4
- v2.17.1

