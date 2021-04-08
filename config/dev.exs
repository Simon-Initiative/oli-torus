use Mix.Config

config :oli,
  env: :dev,
  s3_media_bucket_name: "torus-media-dev",
  media_url: "torus-media-dev.s3.amazonaws.com",
  slack_webhook_url: System.get_env("SLACK_WEBHOOK_URL")

# Configure your database
config :oli, Oli.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  database: System.get_env("DB_NAME", "oli_dev"),
  hostname: System.get_env("DB_HOST", "localhost"),
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  timeout: 600_000,
  ownership_timeout: 600_000

# Configure email for development
config :oli, Oli.Mailer, adapter: Bamboo.LocalAdapter

config :oli, OliWeb.Pow.Mailer, adapter: Bamboo.LocalAdapter

force_ssl =
  case System.get_env("FORCE_SSL", "false") do
    "true" -> [rewrite_on: [:x_forwarded_proto]]
    _ -> false
  end

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :oli, OliWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("HTTP_PORT", "80"))
  ],
  url: [
    scheme: System.get_env("SCHEME", "https"),
    host: System.get_env("HOST", "localhost"),
    port: String.to_integer(System.get_env("PORT", "443"))
  ],
  https: [
    port: 443,
    otp_app: :oli,
    keyfile: "priv/ssl/localhost.key",
    certfile: "priv/ssl/localhost.crt"
  ],
  force_ssl: force_ssl,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Note that this task requires Erlang/OTP 20 or later.
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :oli, OliWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/oli_web/{live,views}/.*(ex)$",
      ~r"lib/oli_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Configure Joken for jwt signing and verification
config :joken, default_signer: "secret"
