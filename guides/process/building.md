# Production Deployments

## Using a Prebuilt Release (Recommended)

Torus releases are built automatically with each new commit to master and uploaded to the public S3 bucket `oli-torus-releases`. These prebuilt releases are created specifically for Amazon Linux 2, but Torus can also be built for any other platform using the [Building a Release](#Building-a-Release) guide below. To download a prebuilt release, start by first identifying the version number and first 7 digits of the release SHA you wish to deploy. These can be found on the [releases page](https://github.com/Simon-Initiative/oli-torus/releases) on the left side of each release (recommended), or alternatively for unstable bleeding-edge builds the [master commit history](https://github.com/Simon-Initiative/oli-torus/commits/master) can be used in combination with whichever version is set in mix.exs for that particular commit.

```
RELEASE_VERSION=0.18.3
RELEASE_SHA=c9d615b

# fetch the release package from the official torus builds S3 bucket
curl --fail -L https://oli-torus-releases.s3.amazonaws.com/oli-${RELEASE_VERSION}-${RELEASE_SHA}.zip -o oli-${RELEASE_VERSION}-${RELEASE_SHA}.zip
```

## Building a Release

Torus recommends using [elixir releases](https://hexdocs.pm/mix/Mix.Tasks.Release.html) for production deployments. You will have to have [Elixir installed on your machine](https://elixir-lang.org/install.html) to build Torus.

A release can be created by executing [the following script](https://github.com/Simon-Initiative/oli-torus/blob/master/.github/actions/torus-builder/entrypoint.sh) in the oli-torus repository with a current git commit SHA set to `RELEASE_SHA`. This will compile a release for the system architecture on which it is executed:

```
# clone the oli-torus repository
cd /tmp
git clone https://github.com/Simon-Initiative/oli-torus.git
cd oli-torus

# setup asset build dependencies
npm install -g yarn
yarn --cwd ./assets

RELEASE_SHA=$(git rev-parse --short HEAD)
sh .github/actions/torus-builder/entrypoint.sh
```

You'll find the newly built release under `_build/prod/rel/oli`. This can be zipped and deployed however you see fit (e.g. sftp, S3 and curl, etc.).

```
cd _build/prod/rel/oli
zip -r ../../../../oli-${RELEASE_SHA}.zip *
```

The release will contain all the necessary binaries to run Torus including the Erlang RunTime System and the BEAM virtual machine (except for NodeJS, which is expected to be installed on the target and available in the torus user's `PATH`). For more information on setting up a production environment, refer to the [Setting Up a Production Server](https://github.com/Simon-Initiative/oli-torus/wiki/Setting-Up-A-Production-Server) guide.

Once a release has been created and deployed to the target machine where you intend to run it, you can
execute predefined [release commands](Setting-Up-a-Production-Server#command-reference) to start/stop/daemonize the app.
To perform any of these though, you must first source the `oli.env` configuration into the current shell to configure the environment.

Configure Environment (**REQUIRED** before running any eval or iex commands)

```
set -a; source ./oli.env
```

Stop the server

```
./oli/bin/oli stop
```

Prepare the release

```
# remove old deployment, if one exists
rm -rf ./oli/

unzip oli-*.zip -d oli
chmod -R +x ./oli

# cleanup release zip
rm -rf ./oli-*.zip
```

Migrate and Seed Database

```
./oli/bin/oli eval "Oli.ReleaseTasks.migrate_and_seed"
```

Restart the server

```
./oli/bin/oli daemon
```

## NOTES

- If you see the following deps build error, you must [install OpenSSL 1.1](https://gist.github.com/fernandoaleman/5459173e24d59b45ae2cfc618e20fe06) in order for AppSignal to compile and work properly.

  ```
  ==> appsignal
  Downloading agent release
  AppSignal installation failed: Could not download archive from any of our mirrors.
  Please make sure your network allows access to any of these mirrors.
  Attempted to download the archive from the following urls:
  - URL: https://appsignal-agent-releases.global.ssl.fastly.net/7376537/appsignal-x86_64-linux-all-static.tar.gz
  - Error (hackney response):
  {:error, {:options, {:insufficient_crypto_support, {:"tlsv1.3", {:versions, [:"tlsv1.3", :"tlsv1.2"]}}}}}

  - URL: https://d135dj0rjqvssy.cloudfront.net/7376537/appsignal-x86_64-linux-all-static.tar.gz
  - Error (hackney response):
  {:error, {:options, {:insufficient_crypto_support, {:"tlsv1.3", {:versions, [:"tlsv1.3", :"tlsv1.2"]}}}}}
  ```
