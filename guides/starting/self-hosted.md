## With self-hosting

There are many different ways to structure your own production instance of Torus. This guide will outline a simple, single-app server method for getting a production instance of torus up-and-running on a linux environment of your choice. These instructions are geared specifically for and tested on Amazon Linux 2 machine, but should be easily adaptable to other linux distros such as Debian or Ubuntu.

If this all seems a bit too technical and you just want to use or try out Torus without maintaining all the infrastructure, check out the Open Learning Initiative's production instance at [proton.oli.cmu.edu](https://proton.oli.cmu.edu) where you can easily get started by creating an authoring account for free.

## Prerequisites

Torus requires a few services that are necessary for it to run, the setup of which however is mostly outside the scope of this guide. The following list outlines these prerequisite services and how they should be configured for Torus:

1. VPS (e.g. AWS, Azure, DigitalOcean, Self-hosted) linux server with SSH access

   - Torus requires NodeJS 15+ to be installed on the deployment machine. If `node` is not available in the torus path, you can use the `NODE_PATH` environment variable to configure the path.
   - Releases are built using openssl11-devel for erlang which means that OpenSSL 1.1.1 is required to be installed on the deployment target.
     ```
     sudo yum install openssl11
     ```

2. S3-Compliant bucket (e.g. AWS S3, Backblaze B2, Self-hosted MinIO), public read-accessible
   - Torus will need the **Access Key ID** and the **Secret Access Key** for writable access
   - Access: **Public**, Block _all_ public access: **Off**
   - Bucket Policy: (replace `<bucket_name>` with the name of your bucket)
     ```
     {
         "Version": "2012-10-17",
         "Statement": [
             {
                 "Sid": "PublicRead",
                 "Effect": "Allow",
                 "Principal": "*",
                 "Action": "s3:GetObject",
                 "Resource": "arn:aws:s3:::<bucket_name>/*"
             }
         ]
     }
     ```
   - Cross-origin resource sharing (CORS):
     ```
     [
         {
             "AllowedHeaders": [
                 "*"
             ],
             "AllowedMethods": [
                 "GET"
             ],
             "AllowedOrigins": [
                 "*"
             ],
             "ExposeHeaders": []
         }
     ]
     ```
3. Postgres 9 or later, network accessible from the VPS/server
   - Torus will need a database **db_username** and **db_password** to access the database.
   - The configured user must have database create permissions for initial setup. Alternatively, the database can be manually created and use the `Oli.ReleaseTasks.migrate_and_seed()` command instead of `Oli.ReleaseTasks.setup()` in the instructions below.

## Initial Setup

### Torus User and Directory

Once you have provisioned a linux server, it is recommended you set up a specific user and directory from which to deploy Torus. This guide will assume a user `torus` and a directory `/torus` from where the app will be deployed.

### Configuration

Get started by opening an SSH session and configuring Torus env.

```
cd /torus
vim oli.env
```

This file will define the necessary configs for torus to run and can also be used to modify various other aspects of the system. Make sure to replace any values in `<brackets>` below. At a minimum, this file should contain:

```
## default administrator
ADMIN_EMAIL=<admin@example.edu>
ADMIN_PASSWORD=<admin password>

## public host name
HOST=<torus.example.edu>

## Used to specify which port to expose the http server on, but doesnt affect the public url.
## useful for when you are using a proxy and need to run torus on a specific port without changing the
## public url
HTTP_PORT=80

## Database url with credentials
DATABASE_URL=ecto://<db_username>:<db_password>@postgres/oli

## Email sending
EMAIL_FROM_NAME="OLI Torus"
EMAIL_FROM_ADDRESS="no-reply@example.edu"
# Optional headers for email error handling
# EMAIL_ERRORS_TO_ADDRESS=<torus-admin@example.edu>
# EMAIL_RETURN_PATH_ADDRESS=<torus-admin@example.edu>

## Amazon AWS S3 and SES email services
AWS_ACCESS_KEY_ID=<your_aws_access_key>
AWS_SECRET_ACCESS_KEY=<your_aws_secret_access_key>
AWS_REGION=<your_aws_region>

## S3 storage service config used for storing and serving media
S3_MEDIA_BUCKET_NAME=<your_s3_media_bucket_name>
MEDIA_URL=<your_s3_media_bucket_url.s3.amazonaws.com>

## Google recaptcha key and secret
RECAPTCHA_SITE_KEY=<your_recaptcha_site_key>
RECAPTCHA_PRIVATE_KEY=<your_recaptcha_private_key>

## Secret key base
## A random 64 byte string. You can generate one by calling: openssl rand -base64 64
SECRET_KEY_BASE=<your_secret_key_base>

## Live view salt
## A random 64 byte string. You can generate one by calling: openssl rand -base64 64
LIVE_VIEW_SALT=<your_liveview_salt>

```

For more configuration variables, see [oli.example.env](https://github.com/Simon-Initiative/oli-torus/blob/master/oli.example.env).

### Deploying a release

Torus releases are built automatically on each new commit to master. These prebuilt releases are created specifically for Amazon Linux 2, but Torus can also be built for any other platform using the [Building Releases and Production Deployments](Building-Releases-for-Production-Deployments) guide and continuing at Step 2.

### Using a Prebuilt Release with Amazon Linux 2 (Recommended)

1. Download a prebuilt release by first identifying the version number and first 7 digits of the release SHA you wish to deploy. These can be found on the [releases page](https://github.com/Simon-Initiative/oli-torus/releases) on the left side of each release (recommended), or alternatively for unstable bleeding-edge builds the [master commit history](https://github.com/Simon-Initiative/oli-torus/commits/master) can be used in combination with whichever version is set in mix.exs for that particular commit.

```
RELEASE_VERSION=0.18.3
RELEASE_SHA=c9d615b

# fetch the release package from the official torus builds S3 bucket
curl --fail -L https://oli-torus-releases.s3.amazonaws.com/oli-${RELEASE_VERSION}-${RELEASE_SHA}.zip -o
oli-${RELEASE_VERSION}-${RELEASE_SHA}.zip

# unzip release
unzip oli-*.zip -d oli
chmod -R +x ./oli

# cleanup release zip
rm -rf ./oli-*.zip
```

2. Import configs

```
set -a; source ./oli.env
```

3. Initialize the Database

```
./oli/bin/oli eval "Oli.ReleaseTasks.setup()"
```

4. Start Torus

```
./oli/bin/oli start
```

### Command Reference

Start

```
./oli/bin/oli start
```

Stop

```
./oli/bin/oli stop
```

Daemonize

```
./oli/bin/oli daemon
```

To learn more about these and other elixir release commands, see https://hexdocs.pm/mix/Mix.Tasks.Release.html

### Attach to Remote iex Shell

This will open a remote iex shell in a running instance

```
./oli/bin/oli remote
```

You can also execute a single command using rpc

```
./oli/bin/oli rpc "IO.puts(:hello)"
```

**NOTE:** Since all Torus modules are available and any public function can be executed, be sure to take care in which functions you call so that you do not put the system into an unstable state. Try to avoid calls that involve the database but if necessary, be sure the function you are calling utilizes transactions in case of failure.

See https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-one-off-commands-eval-and-rpc for more information.

## Useful Release Tasks

**\*\*\*IMPORTANT - RUN THIS BEFORE RUNNING ANY TASK\*\*\***

All of the following tasks require environment configs before running:

```
set -a; source ./oli.env
```

### Initial setup

Create, migrate, and seed the database before first run

```
./oli/bin/oli eval "Oli.ReleaseTasks.setup"
```

### Seed the database

After a new release is deployed, it is a good idea to run this task to apply any migrations

```
./oli/bin/oli eval "Oli.ReleaseTasks.seed"
```

### Migrate the database

After a new release is deployed, it is a good idea to run this task to apply any migrations

```
./oli/bin/oli eval "Oli.ReleaseTasks.migrate"
```

### Rollback a database migration

After a new release is deployed, it is a good idea to run this task to apply any migrations

```
./oli/bin/oli eval "Oli.ReleaseTasks.rollback(:oli, "<migration_version_to_rollback_to>")"
```

### Reset the database

```
############################################################################################
## WARNING! The following command will wipe all data in the database. Please use caution! ##
############################################################################################
## reset the database (requires interactive confirmation)
./oli/bin/oli eval "Oli.ReleaseTasks.reset()"

## reset the database (no interactive confirmation for scripting purposes, you better know what you are doing)
./oli/bin/oli eval "Oli.ReleaseTasks.reset(%{ force: true })"
```

Other public functions defined in [lib/oli/release.ex](https://github.com/Simon-Initiative/oli-torus/blob/master/lib/oli/release.ex) are also available as tasks in this way.

## HAProxy Configuration and SSL Certificates

It is recommended you run torus behind a load balancer or proxy that supports SSL termination and use that to manage SSL certificates. For convenience, a default certificate is provided by torus for development mode only but it is self-signed and therefore will show browser warnings when used.

Torus can either be configured to terminate SSL certificates using `SSL_CERT_PATH ` and `SSL_KEY_PATH ` or can be hosted behind a proxy. The most flexible and straightforward solution is to configure Torus behind a proxy using the `HTTP_PORT` config set to whichever port you intend to point to from your proxy. You can also [setup LetsEncrypt certbot](https://www.digitalocean.com/community/tutorials/how-to-secure-haproxy-with-let-s-encrypt-on-centos-7) to automatically renew SSL certificates before they expire. For example, with `HTTP_PORT=8080` set in `oli.env`, your HAProxy `haproxy.cfg` might look something like this:

```
global
    # SSL options
    ssl-default-bind-ciphers AES256+EECDH:AES256+EDH:!aNULL;
    tune.ssl.default-dh-param 4096

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    option forwardfor

    # never fail on address resolution
    default-server init-addr last,libc,none

frontend http
    bind *:80
    mode http

    # if this is an ACME request to proof the domain owner, then redirect to certbot server
    acl is_acme_challenge path_beg -i /.well-known/acme-challenge/

    redirect scheme https code 301 if !is_acme_challenge !{ ssl_fc }

    use_backend letsencrypt if is_acme_challenge

frontend https
    bind *:443 ssl crt /etc/haproxy/certs/ no-sslv3 no-tls-tickets no-tlsv10 no-tlsv11
    http-response set-header Strict-Transport-Security "max-age=16000000; includeSubDomains; preload;"

    acl no_server nbsrv(www) lt 1
    use_backend maintenance if no_server

    default_backend www

backend letsencrypt
    server letsencrypt 127.0.0.1:54321

backend www
    server www 127.0.0.1:8080 check
    http-request add-header X-Forwarded-Proto https if { ssl_fc }

```

## Firewall Configuration

If your server has a firewall, be sure to open the necessary tcp ports. If using HAProxy, these will probably be `80/tcp` and `443/tcp`. If using a load balancer and you have `HTTP_PORT` configured, then that should be the port you expose.

## Systemd and autostart on reboot

You may want to configure torus as a systemd service to take full advantage of automatic start on reboot, logging, and other facilities.

Here is an example of `/etc/systemd/system/torus.service` configured as a systemd service

```
[Unit]
Description=torus

[Service]
ExecStart=/app/oli/bin/oli start
ExecStop=/app/oli/bin/oli stop


[Install]
WantedBy=multi-user.target
```

This will also require a duplicate of oli.env config file in `/etc/systemd/system/torus.service.d/torusenv.conf` in the format:

```
[Service]
Environment="HOST=mydomain.example.edu"
Environment="PORT=80"

```

## AppSignal

APM for Ruby, Elixir & Node.js that includes error, performance, host, dashboards, anomalies and uptime monitoring. By default it is disabled and is not required for application to run. However, you can choose to activate AppSignal by adding the following ENV variables:

```
APPSIGNAL_OTP_APP="oli"
APPSIGNAL_PUSH_API_KEY="your-push-api-key"
APPSIGNAL_APP_NAME="Torus"
APPSIGNAL_APP_ENV="prod"
```
