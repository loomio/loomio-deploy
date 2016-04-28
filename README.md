# loomio-deploy

This repo is a basic docker-compose configuration for running Loomio on your own server.

This README is a guide to setting up Loomio using this docker-compose based system.

## What you'll need
I assume that you have root access to a server running a default configuration of Ubuntu 14.04 x64.
You'll also need a public IP address for the server and a domain name which you can create DNS records for.
Finally you'll need some kind of SMTP server for sending email. More on that below.

## Network configuration
What hostname will you be using for your Loomio instance? What is the IP address of your server?

For the purposes of this example, the hostname will be loomio.example.com and the IP address is 123.123.123.123


### DNS Records

To allow people to access the site via your hostname you need an A record:

```
A loomio.example.com 123.123.123.123
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

### Create your Loomio ENV file
This step creates an `env` file configured for your hostname. It also creates directories on the host to hold user data.

Remember to change `loomio.example.com` to your hostname for the loomio instance, and give your contact email address for letsencrypt, so you can recover your ssl keys if you need them.
```sh
./scripts/create_env loomio.example.com you@contact.email
```

Now that it exists, have a look inside the file, it's where all your Loomio settings are kept.

```sh
cat env
```

Note: If you change your `env` after you've started the services you need to run `docker-compose down` to remove the existing containers.

### Setup SMTP

Loomio is broken if it cannot send email. In this step you need to edit your `env` file and configure the SMTP settings to get outbound email working.

So you'll need an SMTP server. If you already have one, that's great, you know what to do. For everyone else here are some options to consider:

- For setups that will send less than 99 emails a day [use smtp.google.com](https://www.digitalocean.com/community/tutorials/how-to-use-google-s-smtp-server) for free.

- Look at the (sometimes free) services offered by [SendGrid](https://sendgrid.com/), [SparkPost](https://www.sparkpost.com/), [Mailgun](http://www.mailgun.com/), [Mailjet](https://www.mailjet.com/pricing).

- Soon we'll publish a guide to setting up your own private and secure SMTP server.

Edit the `env` file and enter the right SMTP settings for your setup.

You might need to add an SPF record to indicate that the SMTP can send mail for your domain.

```sh
nano env
```

## Issue an SSL certificate for your hostname:
Thanks to [Let's Encrypt](https://letsencrypt.org/), it's easy to obtain an SSL certificate and encrypt traffic to and from your Loomio instance. Paste this command into your terminal and follow the onscreen instructions.

```sh
docker run -it --rm -p 443:443 -p 80:80 --name letsencrypt \
            -v "/root/loomio-deploy/certificates/:/etc/letsencrypt" \
            -v "/var/lib/letsencrypt:/var/lib/letsencrypt" \
            quay.io/letsencrypt/letsencrypt:latest auth
```

If you have a CA issued certificate or want to generate your own certificate, that's supported too. Just copy your full chain certificate file and the private key file into the `certificates` directory and update the values of `LOOMIO_SSL_KEY` and `LOOMIO_SSL_CERT` in your `env` file.

### Initialize the database
This command initializes a new database for your Loomio instance to use.

```
docker-compose run web rake db:setup
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

## Try it out
visit your hostname in your browser. something like `https://loomio.example.com`.
You should see a login screen, but instead sign up at `https://loomio.example.com/users/sign_up`

## Test the functionality
Test that email is working by visiting `https://loomio.example.com/users/password/new` and get a password reset link sent to you.

Test that live update works with two tabs on the same discussion, write a comment in one, and it should appear in the other.
Test that you can upload files into a thread.
Test that you can reply by email.
test that proposal closing soon works.

todo:
 remove start_group path.
* confirm mailin, pubsub work
* force ssl

## If something goes wrong
confirm `env` settings are correct.
After you change your `env` file you need to restart the system:

```sh
docker-compose restart
```

Other need to know docker commands include:
* `docker ps` lists running containers.
* `docker ps -a` lists all containers.
* `docker logs <container>` to find out what a container is doing.
* `docker stop <container_id or name>` will stop a container
* `docker start <container_id or name>` will start a container
* `docker restart <container_id or name>` will restart a container
* `docker rm <container_id or name>` will delete a container
* `docker pull loomio/loomio:latest` pulls the latest version of loomio
* `docker help <command>` will help you understand commands

To update Loomio to the latest image you'll need to stop, rm, pull, and run again.

```sh
docker stop loomio
docker rm loomio
docker pull loomio/loomio
docker run
```

To login to your running rails app

```sh
docker exec -t -i loomiodeploy_app_1 bundle exec rails console
```

*Need some help?* Check out the [Installing Loomio group](https://www.loomio.org/g/C7I2YAPN/loomio-community-installing-loomio).

## Next steps for this repo
script to enable automatic security updates, ufw, secure ubuntu to good enough standard.
