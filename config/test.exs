use Mix.Config

config :oli,
  env: :test,
  s3_media_bucket_name: "torus-media-test",
  media_url: "d1od6xouqrpl5k.cloudfront.net",
  http_client: Oli.Test.MockHTTP,
  aws_client: Oli.Test.MockAws,
  slack_webhook_url: nil,
  branding: [
    name: "OLI Torus Test",
    logo: "/images/oli_torus_logo.png",
    favicons: "/favicons",
    dark: [
      logo: "/images/oli_torus_logo_dark.png"
    ]
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

config :lti_1p3,
  http_client: Oli.Test.MockHTTP

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :oli, OliWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
