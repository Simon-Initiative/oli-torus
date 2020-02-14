# OLI


[![CI on Branch Push](https://github.com/Simon-Initiative/oli-torus/workflows/CI%20on%20Branch%20Push/badge.svg?branch=master&event=push)](https://github.com/Simon-Initiative/oli-torus/actions?query=workflow%3A%22CI+on+Branch+Push%22)

## Dependencies

Have installed the following:

- Elixir (`$ brew install elixir`)
- Phoenix (`$ mix archive.install hex phx_new 1.4.10`)
- Docker

## Getting Started

1. Copy example configuration env files:
```
$ cp oli.example.env oli.env
$ cp postgres.example.env postgres.env
```

1. Start dockerized postgres 12 via the included docker-compose file:
```
$ docker-compose up -d postgres && docker-compose logs -f
```

1. Install client and server dependencies:
```
$ cd assets && npm install
$ cd ../ && mix deps.get
```

1. Create database
```
$ mix ecto.create
```

1. Run migration to create schema
```
$ mix ecto.migrate
```

1. Start Phoenix server
```
$ mix phx.server
```

1. Open your web browser to `localhost:4000`
