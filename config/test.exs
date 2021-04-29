use Mix.Config

from_boolean_env = fn key, default ->
  System.get_env(key, default)
    |> String.downcase()
    |> (case do
      "true" -> :enabled
      _ -> :disabled
    end),
end


config :oli,
  env: :test,
  load_testing_mode: from_boolean_env.("LOAD_TESTING_MODE", "false"),
  s3_media_bucket_name: "torus-media-test",
  media_url: "d1od6xouqrpl5k.cloudfront.net",
  http_client: Oli.Test.MockHTTP,
  slack_webhook_url: nil

# Configure your database
config :oli, Oli.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: "oli_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  timeout: 600_000,
  ownership_timeout: 600_000

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
