use Mix.Config

# Configure your database
config :oli, Oli.Repo,
  username: System.get_env("TEST_DB_USER", "postgres"),
  password: System.get_env("TEST_DB_PASSWORD", "postgres"),
  database: System.get_env("TEST_DB_NAME", "oli_test"),
  hostname: System.get_env("TEST_DB_HOST", "localhost"),
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :oli, OliWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
