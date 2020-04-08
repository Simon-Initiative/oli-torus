# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :oli,
  ecto_repos: [Oli.Repo]

# Configures the endpoint
config :oli, OliWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "GE9cpXBwVXNaplyUCYbIWqERmC/OlcR5iVMwLX9/W7gzQRxkD1ETjda9E0jW/BW1",
  render_errors: [view: OliWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Oli.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure OAuth
config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile", callback_params: ["type"]]},
    facebook: {Ueberauth.Strategy.Facebook, [default_scope: "email,public_profile", callback_params: ["type"]]},
    identity: {Ueberauth.Strategy.Identity, [
      callback_methods: ["POST"],
      uid_field: :email,
      request_path: "/auth/identity",
      callback_path: "/auth/identity/callback",
    ]}
  ]

google_client_id = System.get_env("GOOGLE_CLIENT_ID") ||
  raise """
  environment variable GOOGLE_CLIENT_ID is missing. You can set this variable in oli.env
  """
google_client_secret = System.get_env("GOOGLE_CLIENT_SECRET") ||
  raise """
  environment variable GOOGLE_CLIENT_SECRET is missing. You can set this variable in oli.env
  """

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: google_client_id,
  client_secret: google_client_secret


facebook_client_id = System.get_env("FACEBOOK_CLIENT_ID") ||
    raise """
    environment variable FACEBOOK_CLIENT_ID is missing.
    You can set this variable in oli.env
    """
facebook_client_secret = System.get_env("FACEBOOK_CLIENT_SECRET") ||
    raise """
    environment variable FACEBOOK_CLIENT_SECRET is missing.
    You can set this variable in oli.env
    """

config :ueberauth, Ueberauth.Strategy.Facebook.OAuth,
  client_id: facebook_client_id,
  client_secret: facebook_client_secret

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
