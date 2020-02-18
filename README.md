# OLI Authoring and Delivery

[![Open Learning Initiative](https://oli.cmu.edu/wp-content/uploads/2018/10/oli-logo-78px-high-1.svg)](http://oli.cmu.edu/)

[![Build & Test CI](https://github.com/Simon-Initiative/oli-torus/workflows/Build%20&%20Test%20CI/badge.svg?branch=master)](https://github.com/Simon-Initiative/oli-torus/actions?query=workflow%3A%22Build+%26+Test+CI%22)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/Simon-Initiative/authoring-client/blob/master/LICENSE)

## Dependencies

Have installed the following:

- Elixir (`$ brew install elixir`)
- Phoenix (`$ mix archive.install hex phx_new 1.4.10`)
- Docker

## Getting Started

### Setup
1. Create configuration env files:
    ```
    $ cp oli.example.env oli.env
    $ cp postgres.example.env postgres.env
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

2. Create database
    ```
    $ docker-compose run app mix ecto.create
    ```

3. Run migration to create schema
    ```
    $ docker-compose run app mix ecto.migrate
    ```

### Running Development Server

1. Start Phoenix server
    ```
    $ docker-compose up -d && docker-compose logs -f
    ```
    > NOTE: `docker-compose down` to stop the server

1. Open your web browser to `localhost:4000`

#### Alternatively, run native development server

1. To use the `oli.env` configuration, we need a helper tool to load the environment variables
    ```
    $ npm install -g env-cmd
    ```

2. Configure `oli.env` for running natively:
    REPLACE:
    ```
    DB_HOST=postgres
    ```

    WITH:
    ```
    DB_HOST=localhost
    ```

3. Start Phoenix server
    ```
    $ env-cmd -f oli.env mix phx.server
    ```
    >NOTE: Press Ctrl+c twice to stop the Phoenix server

4. Open your web browser to `localhost:4000`


### Running Tests

1. Run client tests
    ```
    $ cd assets && npm run test
    ```

1. Run server tests
    ```
    $ mix test
    ```
