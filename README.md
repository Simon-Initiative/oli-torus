# OLI Authoring and Delivery

[![Open Learning Initiative](https://oli.cmu.edu/wp-content/uploads/2018/10/oli-logo-78px-high-1.svg)](http://oli.cmu.edu/)

[![Build & Test CI](https://github.com/Simon-Initiative/oli-torus/workflows/Build%20&%20Test%20CI/badge.svg?branch=master)](https://github.com/Simon-Initiative/oli-torus/actions?query=workflow%3A%22Build+%26+Test+CI%22)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/Simon-Initiative/authoring-client/blob/master/LICENSE)

## Getting Started

### Setup
#### (Quick Start) Run development server with docker-compose

1. Install dependencies:
    - [Docker](https://www.docker.com/) and docker-compose
<br />

1. Initial setup
    ```
    $ docker-compose up -d postgres
    $ docker-compose run app mix ecto.create
    $ docker-compose run app mix ecto.migrate
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
    - [Phoenix](https://www.phoenixframework.org/) (`$ mix archive.install hex phx_new 1.4.10`)
<br/>

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
    $ cd assets && npm install
    ```

1. Create database
    ```
    $ mix ecto.create
    ```

2. Run migration to create schema
    ```
    $ mix ecto.migrate
    ```

3. To use the `oli.env` configuration, we need a helper tool to load the environment variables
    ```
    $ npm install -g env-cmd
    ```

4. Start Phoenix server
    ```
    $ env-cmd -f oli.env mix phx.server
    ```
    > NOTE: Use Ctrl+c to stop the Phoenix server

5. Open your web browser to `localhost:4000`


### Running Tests

1. Run client tests
    ```
    $ cd assets && npm run test
    ```

1. Run server tests
    ```
    $ mix test
    ```
