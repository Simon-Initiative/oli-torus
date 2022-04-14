import Config

config :oli,
  env: :test,
  prometheus_port: 9570,
  s3_media_bucket_name: System.get_env("TEST_S3_MEDIA_BUCKET_NAME"),
  media_url: System.get_env("TEST_MEDIA_URL"),
  http_client: Oli.Test.MockHTTP,
  aws_client: Oli.Test.MockAws,
  slack_webhook_url: nil,
  branding: [
    name: "OLI Torus Test",
    logo: "/images/oli_torus_logo.png",
    logo_dark: "/images/oli_torus_logo_dark.png",
    favicons: "/favicons"
  ]

# Configure your database
config :oli, Oli.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: "oli_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  timeout: 600_000,
  ownership_timeout: 600_000

config :oli, Oban,
  plugins: false,
  queues: false

# Configure reCAPTCHA
config :oli, :recaptcha,
  verify_url: "https://www.google.com/recaptcha/api/siteverify",
  timeout: 5000,
  site_key: System.get_env("RECAPTCHA_SITE_KEY", "6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI"),
  secret: System.get_env("RECAPTCHA_PRIVATE_KEY", "6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe")

# Configure help
config :oli, :help, dispatcher: Oli.Help.Providers.EmailHelp

# Configure Email
config :oli, Oli.Mailer, adapter: Bamboo.TestAdapter

config :oli, OliWeb.Pow.Mailer, adapter: Bamboo.TestAdapter

# speed up tests by lowering the hash iterations
config :bcrypt_elixir, log_rounds: 4

config :lti_1p3,
  http_client: Oli.Test.MockHTTP

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :oli, OliWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

truncate =
  System.get_env("LOGGER_TRUNCATE", "8192")
  |> String.downcase()
  |> case do
    "infinity" ->
      :infinity

    val ->
      String.to_integer(val)
  end

config :logger, truncate: truncate

config :appsignal, :config, active: false

config :oli, :auth_providers,
  google_client_id: System.get_env("GOOGLE_CLIENT_ID", "client_id"),
  google_client_secret: System.get_env("GOOGLE_CLIENT_SECRET", "client_secret"),
  author_github_client_id: System.get_env("AUTHOR_GITHUB_CLIENT_ID", "author_client_id"),
  author_github_client_secret:
    System.get_env("AUTHOR_GITHUB_CLIENT_SECRET", "author_client_secret"),
  user_github_client_id: System.get_env("USER_GITHUB_CLIENT_ID", "user_client_id"),
  user_github_client_secret: System.get_env("USER_GITHUB_CLIENT_SECRET", "user_client_secret")
