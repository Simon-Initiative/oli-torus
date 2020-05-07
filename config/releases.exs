# In this file, we load production configuration and secrets
# from environment variables at runtime
import Config

database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :oli, Oli.Repo,
  # ssl: true,
  url: database_url,
  database: System.get_env("DB_NAME", "oli"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

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

config :oli, OliWeb.Endpoint,
  server: true,
  http: [:inet6, port: String.to_integer(System.get_env("PORT") || "80")],
  url: [host: host, port: String.to_integer(System.get_env("PORT") || "80")],
  secret_key_base: secret_key_base,
  live_view: [signing_salt: live_view_salt]

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
#     config :oli, OliWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
