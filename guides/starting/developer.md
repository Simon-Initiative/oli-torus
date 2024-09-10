# As a developer

These instructions will set up a development environment
with the Torus server running directly on the host machine.

## Mostly Automated Steps

1. Install dependencies:

   - [Docker](https://www.docker.com/) and docker-compose
   - [Elixir](https://elixir-lang.org/) (`$ brew install elixir`)
   - [Phoenix](https://www.phoenixframework.org/) (`$ mix archive.install hex phx_new 1.5.9`)

1. Clone this repository `$ git clone https://github.com/Simon-Initiative/oli-torus`

1. Run `$ sh ./devmode.sh`

1. Run `$ mix phx.server`

1. Open your web browser to `https://localhost`.

## Mostly Manual Steps

1. Install dependencies:

   - [Docker](https://www.docker.com/) and docker-compose
   - [Elixir](https://elixir-lang.org/) (`$ brew install elixir`)
   - [Phoenix](https://www.phoenixframework.org/) (`$ mix archive.install hex phx_new 1.5.9`)

1. Clone this repository `$ git clone https://github.com/Simon-Initiative/oli-torus`

1. Create configuration env files:

   ```
   $ cp oli.example.env oli.env
   $ cp postgres.example.env postgres.env
   ```

1. Configure `oli.env` for running natively:

   Make sure `DB_HOST` is set to `localhost` (as opposed to `postgress`).

   ```
   DB_HOST=localhost
   ```

1. Start dockerized postgres 12 via the included docker-compose file:

   ```
   $ docker-compose up -d postgres
   ```

1. Install server and client dependencies:

   ```
   $ mix deps.get
   $ cd assets && yarn
   ```

1. Build frontend assets

   ```
   $ yarn deploy
   ```

1. Create database

   ```
   $ cd ../ && mix ecto.create
   ```

1. Run migration to create schema

   ```
   $ mix ecto.migrate
   ```

1. Seed the database

   ```
   $ mix run priv/repo/seeds.exs
   ```

1. Configure bash to properly source environment variable configurations

   ```
   $ set -a
   ```

1. Load phoenix app configuration from environment file. This step is necessary anytime you change a configuration variable

   ```
   $ source oli.env
   ```

1. Start Phoenix server

   ```
   $ mix phx.server
   ```

   > **Note**: Use Ctrl+c to stop the Phoenix server

1. Open your web browser to `https://localhost`.

### Notes

> In order to sign in, you must use **https** and accept the self-signed cert browser warning to avoid CSRF issues. If you would like to provide your own cert instead of accepting the included one, simply replace `priv/ssl/localhost.crt` -or- use the localhost tunneling method below to generate a public URL with SSL enabled.

> To access email verification message and activate your locally-created account, visit `http://localhost/dev/sent_emails`.

> Default administrator credentials are defined in `oli.env` as `ADMIN_EMAIL` and `ADMIN_PASSWORD`. These values are only used to seed the database during `mix ecto.setup` / `mix ecto.reset`.

> Docker is not a strict dependency. We use it here to simplify the install and running of Postgres. You can choose to install and run Postgres bare-metal, but you will not be able to use the **Mostly Automated Steps** above (since the `./devmode.sh` script depends on Docker).

## Running Tests

> **Note**: If you are running using docker-compose as described in [**Quick Start**](Quick-Start), you can create a bash session to execute any of the following commands using `docker-compose exec app bash`

1. Run JavaScript tests

   ```
   $ cd assets && yarn test
   ```

1. Run elixir tests

   ```
   $ mix test
   ```

1. Run elixir tests for a specific file, watch for changes and automatically re-run tests

   ```
   $ mix test.watch --stale --max-failures 1 --trace --seed 0 lib/some_dir/file_to_watch.ex
   ```

   Re-run only failed tests

   ```
   $ mix test.watch --failed --trace --seed 0 lib/some_dir/file_to_watch.ex
   ```

   Using fswatch, re-run only the test files that have changed as well as the tests that have gone stale due to changes in lib and pause on any failures

   ```
   $ fswatch lib test | mix test --listen-on-stdin --stale --seed 0 --trace --max-failures 1
   ```

1. Generate an html coverage report

   ```
   $ mix coveralls.html
   ```

1. Occasionally the test database will need to be reset (e.g. if tests were cancelled partway through)
   ```
   $ MIX_ENV=test mix ecto.reset
   ```

## Tunneling localhost connection for LTI development

When making an LTI connection from an LMS such as Canvas, we need an internet accessible FQDN with SSL to properly configure a connection. The service ngrok offers an easy to use command line tool that does just this.

1. [Download ngrok](https://ngrok.com/) and install using their instructions (Create a free account if required)
1. Run ngrok locally to tunnel to phoenix app on port 4000
   `ngrok http 4000`
1. Access your running webapp using the generated https address (shown in console after `Forwarding`). This will be the same address used to configure the LMS LTI connection

## Configuring an LTI 1.3 Connection

Torus supports LTI 1.3 integration and leverages the Learning Management System for course delivery.

To configure an LTI connection, refer to the [Torus LTI 1.3 Manual Configuration](https://github.com/Simon-Initiative/oli-torus/wiki/Torus-LTI-1.3-Configuration).
