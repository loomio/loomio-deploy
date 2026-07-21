# Deploy your own Loomio

This is what you need to run your own Loomio server.

It will run all Loomio services on a single host via docker and docker compose, complete with an SSL certificate via letsencrypt.

If you just want a local install of Loomio for development, see [Setting up a Loomio development environment](https://github.com/loomio/loomio/blob/master/DEVSETUP.md).

## What you'll need
* Root access to a server, on a public IP address, running Ubuntu (latest LTS release) with at least 1GB RAM.

* A domain name

* An SMTP server

## Network configuration
For this example, the hostname will be loomio.example.com and the IP address is 192.0.2.1

### DNS Records
To allow people to access the site via your hostname you need an A record:

```
A loomio.example.com, 192.0.2.1
```

Loomio supports "Reply by email" and to enable this you need an MX record so mail servers know where to direct these emails.

```
MX loomio.example.com, loomio.example.com, priority 0
```

Additionally, create a CNAME record for the collaborative editing server.

```
CNAME hocuspocus.loomio.example.com, loomio.example.com
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
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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
./create_swapfile.sh
```

### Create your ENV files
This script creates a `.env` file configured for you.

Remember to change the values to your hostname and contact email address. This is for the LetsEncypt service.

```sh
./create_env.sh loomio.example.com you@contact.email
```

Now have a look inside the files:

```sh
cat .env
```

Looking for SSO (SAML, OAUTH, Google etc), Theme logo and color settings, or other feature flags? [It's all in the ENV file](/env_template)

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

## Background jobs and Redis

Background jobs run with Solid Queue and are stored in PostgreSQL. The `worker` service starts Solid Queue automatically, and instance administrators can monitor jobs at `/admin/jobs`.

Redis is used only for caching and Action Cable. It is recommended for production installations because moving cache and live-update traffic to PostgreSQL can place substantial additional load on the database.

The default Redis service is configured as a bounded, non-persistent cache. It disables RDB and append-only persistence, and uses `allkeys-lru` eviction when it reaches `REDIS_MAXMEMORY`. Losing Redis data may cause cache misses or live clients to reconnect, but it does not lose jobs, sessions, or primary application data.

Set the memory limit in `.env`:

```sh
REDIS_MAXMEMORY=256mb
```

Loomio also supports running without Redis. Remove `REDIS_CACHE_URL`, the Redis service, and the app service's Redis dependency to use PostgreSQL-backed Solid Cache and Solid Cable instead. This is intended for small or low-traffic installations.

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
./update.sh
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

## Push notifications (optional)

Loomio supports browser push notifications. To enable them, you need to generate VAPID keys and add them to your `.env` file.

### Generate VAPID keys

Run this from within the Loomio container:

```sh
docker compose run app ruby -e "require 'web_push'; keys = WebPush.generate_key; puts \"VAPID_PUBLIC_KEY=#{keys.public_key}\"; puts \"VAPID_PRIVATE_KEY=#{keys.private_key}\""
```

### Add to `.env`

Copy the output into your `.env` file:

```
VAPID_PUBLIC_KEY=BGxH...your_public_key...
VAPID_PRIVATE_KEY=your_private_key
```

Then restart:

```sh
docker compose down
docker compose up -d
```

Users can then enable push notifications from the **Push notification devices** page in their settings sidebar.

## Upgrading from Sidekiq to Solid Queue

Loomio 3.1 replaces Sidekiq with Solid Queue. Outstanding Sidekiq jobs are not transferred automatically. Skipping them does not prevent the upgrade or affect primary application data.

To process outstanding jobs before upgrading, stop the application and worker while they are still running the old Sidekiq-enabled image:

```sh
docker compose stop app worker
docker compose run --rm -v "./drain_sidekiq_before_job_cutover.rb:/tmp/drain_sidekiq_before_job_cutover.rb:ro" app bundle exec rails runner /tmp/drain_sidekiq_before_job_cutover.rb
```

The script executes queued and scheduled jobs, removing each one after it succeeds. Scheduled jobs run immediately, even when their scheduled time has not arrived. Retry and dead jobs are reported but are not executed.

After reviewing the output, run `./update.sh`. The new `worker` service starts Solid Queue through `bin/jobs start`.

# Updating old versions of Loomio

Please upgrade through the following versions. You need to edit `.env` and change LOOMIO_CONTAINER_TAG to each version, then run `./update.sh`. When the migrations have completed, apply the next tag and repeat.

- v2.4.2
- v2.8.8
- v2.11.13
- v2.15.4
- v2.17.1
