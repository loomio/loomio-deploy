# Deploy your own Loomio

This is what you need to run your own Loomio server.

It will run all Loomio services on a single host via docker and docker-compose, complete with an SSL certificate via letsencrypt.

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

Additionally, create a CNAME record that points `channels.loomio.example.com` to `loomio.example.com`. The records would look like this:

```
channels.loomio.example.com.    600    IN    CNAME    loomio.example.com.
loomio.example.com.    600    IN    A    123.123.123.123
```

## Configure the server

### Login as root
To login to the server, open a terminal window and type:

```sh
ssh -A root@loomio.example.com
```

### Install docker and docker-compose

These commands install docker and docker-compose, copy and paste.

```sh
snap install docker
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
docker-compose up -d db
docker-compose run app rake db:setup
```

### Install crontab
Doing this tells the server what regular tasks it needs to run. These tasks include:

* Noticing which proposals are closing in 24 hours and notifying users.
* Closing proposals and notifying users they have closed.
* Sending "Yesterday on Loomio", a digest of activity users have not already read. This is sent to users at 6am in their local timezone.

Run `crontab -e` and append the following line:

```
0 * * * *  /snap/bin/docker exec loomio-worker bundle exec rake loomio:hourly_tasks > ~/rake.log 2>&1
```

## Starting the services
This command starts the database, application, reply-by-email, and live-update services all at once.

```
docker-compose up -d
```

Give it a minute to start, then visit your URL while crossing your fingers!

If you visit the url with your browser and the rails server is not yet running, but nginx is, you'll see a "503 bad gateway" error message.

You'll want to see the logs as it all starts, run the following command:

```
docker-compose logs -f
```

## Try it out

visit your hostname in your browser.

Once you have signed in (and confirmed your email), grant yourself admin rights

```
docker-compose run app rails c
User.last.update(is_admin: true)
```

you can now access the admin interface at https://loomio.example.com/admin


## If something goes wrong

To see system error messages as they happen run `docker-compose logs -f` and make a request against the server.

If you want to be notified of system errors you could setup [Sentry](https://sentry.io/) and add it to the env.

Confirm `env` settings are correct.

After you change your `env` files you need to restart the system:

```sh
docker-compose down
docker-compose up -d
```

To update Loomio to the latest image you'll need to stop, rm, pull, apply potential changes to the database schema, and run again.

```sh
docker-compose pull
docker-compose down
docker-compose run app rake db:migrate
docker-compose up -d
```

From time to time, or if you are running out of disk space (check `/var/lib/docker`):

```sh
docker system prune
```

It can be helpful to wrap all these commands together in a single line to update Loomio:

```sh
docker system prune -f; docker-compose pull; docker-compose run app rake db:migrate; docker-compose down; docker-compose up -d
```

To login to your running rails app console:

```sh
docker-compose run app rails c
```

A PostgreSQL shell to inspect the database:

```sh
docker exec -ti loomio-db su - postgres -c 'psql loomio_production'
```

## Backups
Database backups are automatic in the default configuration, you'll find them in the `pgdumps` directory. See [prodrigestivill/docker-postgres-backup-local](https://github.com/prodrigestivill/docker-postgres-backup-local) for more information, including how to restore a backup.

# Updating old versions of Loomio

Please upgrade through the following versions to ensure that migrations work

- v2.4.2
- v2.8.8
- v2.11.13
- v2.17.1

