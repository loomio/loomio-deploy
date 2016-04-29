# Deploy your own Loomio

This repo contains a basic docker-compose configuration for running Loomio on your own server.

It assumes you want to run everything on a single host. It automatically issues
an SSL certificate for you via the amazing [letsencrypt.org](https://letsencrypt.org/).

## What you'll need
* Root access to a server, on a public IP address, running a default configuration of Ubuntu 14.04 x64.

* A domain name which you can create DNS records for.

* An SMTP server for sending email. More on that below.

## Network configuration
What hostname will you be using for your Loomio instance? What is the IP address of your server?

For the purposes of this example, the hostname will be loomio.example.com and the IP address is 123.123.123.123

### DNS Records

To allow people to access the site via your hostname you need an A record:

```
A loomio.example.com, 123.123.123.123
```

You also need to setup a CNAME record for the live update service

```
CNAME faye.loomio.example.com, loomio.example.com
```

Loomio supports "Reply by email" and to enable this you need an MX record so mail servers know where to direct these emails.

```
MX loomio.example.com, loomio.example.com, priority 0
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
wget -qO- https://get.docker.com/ | sh
wget -O /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/1.6.2/docker-compose-`uname -s`-`uname -m`
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
This script creates `env` and `faye_env` files configured for you. It also creates directories on the host to hold user data.

When you run this, remember to change `loomio.example.com` to your hostname, and give your contact email address, so you can recover your SSL keys later if required.

```sh
./scripts/create_env loomio.example.com you@contact.email
```

Now have a look inside the files:

```sh
cat env
```

and

```sh
cat faye_env
```


### Setup SMTP

Loomio is technically broken if it cannot send email. In this step you need to edit your `env` file and configure the SMTP settings to get outbound email working.

So, you'll need an SMTP server. If you already have one, that's great, you know what to do. For everyone else here are some options to consider:

- For setups that will send less than 99 emails a day [use smtp.google.com](https://www.digitalocean.com/community/tutorials/how-to-use-google-s-smtp-server) for free.

- Look at the (sometimes free) services offered by [SendGrid](https://sendgrid.com/), [SparkPost](https://www.sparkpost.com/), [Mailgun](http://www.mailgun.com/), [Mailjet](https://www.mailjet.com/pricing).

- Soon we'll publish a guide to setting up your own private and secure SMTP server.

Edit the `env` file and enter the right SMTP settings for your setup.

You might need to add an SPF record to indicate that the SMTP can send mail for your domain.

```sh
nano env
```

### Initialize the database
This command initializes a new database for your Loomio instance to use.

```
docker-compose run loomio rake db:setup
```

### Install crontab
Doing this tells the server what regular tasks it needs to run. These tasks include:

* Noticing which proposals are closing in 24 hours and notifying users.
* Closing proposals and notifying users they have closed.
* Sending "Yesterday on Loomio", a digest of activity users have not already read. This is sent to users at 6am in their local timezone.

The following command appends some lines of text onto the system crontab file.

```
cat crontab >> /etc/crontab
```

## Starting the services
This command starts the database, application, reply-by-email, and live-update services all at once.

```
docker-compose up -d
```

You'll want to see the logs as it all starts, run the following command:

```
docker-compose logs
```

## Try it out
visit your hostname in your browser. something like `https://loomio.example.com`.
You should see a login screen, but instead sign up at `https://loomio.example.com/users/sign_up`

## Test the functionality
Test that email is working by visiting `https://loomio.example.com/users/password/new` and get a password reset link sent to you.

Test that live update works with two tabs on the same discussion, write a comment in one, and it should appear in the other.
Test that you can upload files into a thread.
Test that you can reply by email.
test that proposal closing soon works.

## If something goes wrong
confirm `env` settings are correct.

After you change your `env` file you need to restart the system:
run `docker-compose down` then `docker-compose up -d`

To update Loomio to the latest image you'll need to stop, rm, pull, and run again.

```sh
docker-compose down
docker-compose pull
docker-compose up -d
```

To login to your running rails app console:

```sh
docker exec loomiodeploy_worker_1 bundle exec rails console
```

*Need some help?* Visit the [Installing Loomio group](https://www.loomio.org/g/C7I2YAPN/loomio-community-installing-loomio).
