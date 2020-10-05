# OLI Authoring and Delivery

[![Open Learning Initiative](https://oli.cmu.edu/wp-content/uploads/2018/10/oli-logo-78px-high-1.svg)](http://oli.cmu.edu/)

[![Build & Test CI](https://github.com/Simon-Initiative/oli-torus/workflows/Build%20&%20Test%20CI/badge.svg?branch=master)](https://github.com/Simon-Initiative/oli-torus/actions?query=workflow%3A%22Build+%26+Test+CI%22)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/Simon-Initiative/authoring-client/blob/master/LICENSE)

## Getting Started

### Setup
#### (Quick Start) Run development server with docker-compose

1. Install dependencies:
    - [Docker](https://www.docker.com/) and docker-compose

1. Initial setup
    ```
    $ docker-compose up -d postgres
    $ docker-compose run app mix ecto.create
    $ docker-compose run app mix ecto.migrate
    $ docker-compose run app mix run priv/repo/seeds.exs
    ```

1. Start Phoenix server
    ```
    $ docker-compose up -d && docker-compose logs -f
    ```
    > NOTE: Use Ctrl+c to exit log streaming and `docker-compose down` to stop the server.

1. Open your web browser to `localhost:4000`

#### Run development server natively

1. Install dependencies:
    - [Docker](https://www.docker.com/) and docker-compose
    - [Elixir](https://elixir-lang.org/) (`$ brew install elixir`)
    - [Phoenix](https://www.phoenixframework.org/) (`$ mix archive.install hex phx_new 1.5.3`)

1. Optionally, use the provided `devmode.sh` script to automatically run all the following steps and get started
   ```
   $ sh ./devmode.sh
   ```

   Skip the remaining setup steps and use `mix phx.server` to run the server.

1. Create configuration env files:
    ```
    $ cp oli.example.env oli.env
    $ cp postgres.example.env postgres.env
    ```

1. Configure `oli.env` for running natively:
    REPLACE:
    ```
    DB_HOST=postgres
    ```

    WITH:
    ```
    DB_HOST=localhost
    ```

1. Start dockerized postgres 12 via the included docker-compose file:
    ```
    $ docker-compose up -d postgres && docker-compose logs -f
    ```

1. Install server and client dependencies:
    ```
    $ mix deps.get
    $ cd assets && yarn
    ```

1. Create database
    ```
    $ cd ../ && mix ecto.create
    ```

1. Run migration to create schema
    ```
    $ mix ecto.migrate
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
    > NOTE: Use Ctrl+c to stop the Phoenix server

1. Open your web browser to `localhost:4000`


### Running Tests

If using docker-compose, you can start a bash session to execute any of the following commands using `docker-compose exec app bash`

1. Run client tests
    ```
    $ cd assets && npm run test
    ```

1. Run server tests
    ```
    $ mix test
    ```

### Tunneling localhost connection for LTI development

When making an LTI connection from an LMS such as Canvas, we need an internet accessible FQDN with SSL to properly configure a connection. The service ngrok offers an easy to use commandline tool that does just this (ngrok - secure introspectable tunnels to ngrok.

1. [Download ngrok](https://ngrok.com/) and install using their instructions (Create a free account if required)
1. Run ngrok locally to tunnel to phoenix app on port 4000
        ```
        ngrok http 4000
        ```
1. Access your running webapp using the generated https address (shown in console after `Forwarding`). This will be the same address used to configure the LMS LTI connection
