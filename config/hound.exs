import Config

import_config "dev.exs"

# set HEADLESS=false env var to view the browser during tests.
#  > HEADLESS=false mix test.hound
chrome_args =
  case System.get_env("HEADLESS", "true") do
    "true" -> ["--headless", "--disable-gpu", "--allow-insecure-localhost"]
    _ -> ["--allow-insecure-localhost"]
  end

config :hound,
  retries: 15,
  retry_time: 2000,
  driver: "chrome_driver",

  # Chromedriver url to connect to:
  host: "http://localhost",

  # Chromedriver port to connect to:
  port: 9515,
  chrome_args: chrome_args,

  # Base url of our test instance
  torus_base_url: "https://localhost:9443"

config :oli,
  env: :test,
  prometheus_port: 9569

config :oli, OliWeb.Endpoint,
  server: true,
  http: [
    port: 9080
  ],
  url: [
    scheme: "https",
    host: "localhost",
    port: 9443
  ],
  https: [
    port: 9443,
    otp_app: :oli,
    keyfile: "priv/ssl/localhost.key",
    certfile: "priv/ssl/localhost.crt"
  ],
  debug_errors: true,
  code_reloader: false,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch",
      "--watch-options-stdin",
      cd: Path.expand("../assets", __DIR__)
    ],
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--config",
      "webpack.config.node.js",
      "--mode",
      "production",
      "--watch",
      "--watch-options-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

config :oli, Oli.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: "oli_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  timeout: 600_000,
  ownership_timeout: 600_000

config :logger, level: :warn
