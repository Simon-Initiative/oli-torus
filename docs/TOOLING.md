# Tooling

## Commands

- `asdf` via [`.tool-versions`](/Users/darren/dev/oli-torus/.tool-versions) for pinned Erlang, Elixir, Node.js, Yarn, and Python versions
- `mix` for backend dependency management, compilation, database tasks, tests, formatting, and the Phoenix server
- `yarn` in `assets/` for frontend dependencies, tests, linting, formatting, and bundling
- `devmode.sh` as the main native-development convenience entrypoint for first-run setup, local env loading, Postgres startup, and MinIO setup
- `docker compose` for local supporting services such as Postgres, MinIO, and ClickHouse
- Webpack via `assets/webpack.config.js` and related configs for frontend bundling
- Phoenix/Tailwind asset pipeline via Mix aliases such as `mix assets.deploy`
- Jest for frontend unit tests
- ESLint and Prettier for TypeScript linting and formatting
- Storybook is available in `assets/` for UI component development and preview workflows
- Typedoc tooling is available for activity SDK documentation generation

## Required Gates

- backend changes should run the relevant `mix test` targets and `mix format`
- frontend changes should run the relevant `yarn test`, `yarn lint`, and formatting commands under `assets/`
- broader CI and deployment packaging are handled through GitHub Actions

## Canonical Commands

- `mix deps.get`
- `mix phx.server`
- `mix test`
- `mix ecto.setup`
- `mix ecto.reset`
- `cd assets && yarn install`
- `cd assets && yarn test`
- `cd assets && yarn lint`
- `cd assets && yarn format`
- `cd assets && yarn watch`
- `./devmode.sh`
