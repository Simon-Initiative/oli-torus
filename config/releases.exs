# In this file, we load production configuration and secrets
# from environment variables at runtime
import Config

from_boolean_env = fn key, default ->
  System.get_env(key, default)
  |> String.downcase()
  |> case do
    "true" -> :enabled
    _ -> :disabled
  end
end

database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :oli, Oli.Repo,
  url: database_url,
  database: System.get_env("DB_NAME", "oli"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  timeout: 600_000,
  ownership_timeout: 600_000

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

live_view_salt =
  System.get_env("LIVE_VIEW_SALT") ||
    raise """
    environment variable LIVE_VIEW_SALT is missing.
    You can generate one by calling: mix phx.gen.secret
    """

host =
  System.get_env("HOST") ||
    raise """
    environment variable HOST is missing.
    For example: host.example.com
    """

# General OLI app config
config :oli,
  email_from_name: System.get_env("EMAIL_FROM_NAME", "OLI Torus"),
  email_from_address: System.get_env("EMAIL_FROM_ADDRESS", "admin@example.edu"),
  email_reply_to: System.get_env("EMAIL_REPLY_TO", "admin@example.edu"),
  slack_webhook_url: System.get_env("SLACK_WEBHOOK_URL"),
  load_testing_mode: from_boolean_env.("LOAD_TESTING_MODE", "false")

# Configure reCAPTCHA
config :oli, :recaptcha,
  verify_url: "https://www.google.com/recaptcha/api/siteverify",
  timeout: 5000,
  site_key: System.get_env("RECAPTCHA_SITE_KEY"),
  secret: System.get_env("RECAPTCHA_PRIVATE_KEY")

# Configure help
config :oli, :help, dispatcher: Oli.Help.Providers.FreshdeskHelp

config :oli, OliWeb.Endpoint,
  server: true,
  http: [
    :inet6,
    port: String.to_integer(System.get_env("HTTP_PORT", "80"))
  ],
  url: [
    scheme: System.get_env("SCHEME", "https"),
    host: host,
    port: String.to_integer(System.get_env("PORT", "443"))
  ],
  secret_key_base: secret_key_base,
  live_view: [signing_salt: live_view_salt]

# Configure Mnesia directory (used by pow persistent sessions)
config :mnesia, :dir, to_charlist(System.get_env("MNESIA_DIR", ".mnesia"))

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
#     config :oli, OliWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
