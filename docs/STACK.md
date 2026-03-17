# Stack

## Languages

- Elixir for the core application, domain logic, web layer, and background processing
- TypeScript for browser applications, client state, and activity UIs
- Python for OLAP / ETL Lambda-style data processing and analytics-adjacent jobs

## Frameworks And Runtime

- Phoenix as the main web framework
- Phoenix LiveView for server-driven interactive UI flows
- Ecto for database access and persistence
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
