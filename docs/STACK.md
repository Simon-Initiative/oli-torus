# Stack

## Languages

- Elixir for the core application, domain logic, web layer, and background processing
- TypeScript for browser applications, client state, and activity UIs
- Gleam for shared, strongly typed functional subsystems that need to run on both BEAM and JavaScript targets, starting with the math parser and evaluation work under `gleam/`
- Python for OLAP / ETL Lambda-style data processing and analytics-adjacent jobs

## Frameworks And Runtime

- Phoenix as the main web framework
- Phoenix LiveView for server-driven interactive UI flows
- Ecto for database access and persistence
- Gleam's Erlang target for server-side integration with Elixir, and Gleam's JavaScript target for browser-side reuse through the asset pipeline
- React for focused client-side applications embedded into Phoenix pages
- Web Components / custom elements as the client-side activity framework, with React-backed authoring and delivery elements
- `janus-script` as part of the client-side activity and adaptivity runtime
- Oban for background jobs
- Cachex for application caching
- LTI 1.3 as a first-class LMS integration boundary

## Storage And Analytics

- PostgreSQL as the primary transactional database
- ClickHouse as the OLAP / analytics store
- AWS S3 for media, xAPI permanent storage

## Build And Frontend Tooling

- Webpack for frontend bundling
- Jest for frontend tests
- ESLint and Prettier for TypeScript formatting and linting
- Gleam CLI for Gleam dependency management, formatting, compilation, and tests
