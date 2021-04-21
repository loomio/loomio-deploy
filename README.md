# Deploy your own Loomio

This repo contains a docker-compose configuration for running Loomio on your own server.

If you just want a local install of Loomio for development, see [Setting up a Loomio development environment](https://help.loomio.org/en/dev_manual/setup_dev_environment/).

It runs multiple services on a single host with docker and docker-compose. It automatically issues
an SSL certificate for you via the amazing [letsencrypt.org](https://letsencrypt.org/).

## What you'll need
* Root access to a server, on a public IP address, running a recent Ubuntu with at least 1GB RAM (2GB recommended).

* A domain name which you can create DNS records for.

* An SMTP server for sending email.

## Network configuration
What hostname will you be using for your Loomio instance? What is the IP address of your server?

For the purposes of this example, the hostname will be loomio.example.com and the IP address is 123.123.123.123

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
sudo curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
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
cat env
```

### Usage reporting

By default your Loomio instance will report back to www.loomio.org with the number of discussions, comments, polls, stances, users and visits that your site has had.

To be super clear, this does not transfer private data: no user_ids, no user created content, no titles, no names. Simply a count of the number of records you have.

Once per day it will send those numbers and your hostname to us, so that we are able to measure Loomio usage around the world, so that we can tell what impact our work is having.

If you wish to disable this reporting function, add the following line to your `env` file.

```
DISABLE_USAGE_REPORTING=1
```

__My request to you, is that you do not disable usage reporting__. It's really encouraging to see other active instances of Loomio, and the information can help us report our impact as a social enterprise and business.

### Setup SMTP

You need to bring your own SMTP server for Loomio to send emails.

If you already have and SMTP, that's great, put the settings into the `env` file.

For everyone else here are some options to consider:

- Look at the (sometimes free) services offered by [SendGrid](https://sendgrid.com/), [SparkPost](https://www.sparkpost.com/), [Mailgun](http://www.mailgun.com/), [Mailjet](https://www.mailjet.com/pricing).

- Setup your own SMTP server with something like Haraka

Edit the `env` file and enter the right SMTP settings for your setup.

You might also need to add an SPF DNS record to indicate that the SMTP can send mail for your domain.

```sh
nano env
```

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

Run `crontab -e` and apped the following line:

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

To login to your running rails app console:

```sh
docker-compose run app rails c
```

A PostgreSQL shell to inspect the database:

```sh
docker exec -ti loomio-db su - postgres -c 'psql loomio_production'
```

## Backups
We have provided a simple backup script to create a tgz file with a database dump and all the user uploads and system config.

```
scripts/create_backup .
```
Your backup will be in loomio-deploy/backups/

You may wish to add a crontab entry like this. I'll leave it up to you to configure s3cmd and your aws bucket.
```
0 0 * * *  ~/loomio-deploy/scripts/create_backup ~/loomio-deploy > ~/backup.log 2>&1; s3cmd put ~/loomio-deploy/backups/* s3://somebucket/$(date +\%F)/ > ~/s3cmd.log 2>&1

```

# Integrations

## Login via Nextcloud
Loomio must be registered in nextcloud as oauth 2.0 client using https://loomio.example.com/nextcloud/authorize as redirection URL.

In loomio the NEXTCLOUD_HOST environment variable must point to the nextcloud instance, for example https://nextcloud.example.com. NEXTCLOUD_APP_KEY and NEXTCLOUD_APP_SECRET must be set to the client identifier and secret set by nextcloud.
