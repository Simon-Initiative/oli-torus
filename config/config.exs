# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

default_sha = if Mix.env == :dev, do: "DEV BUILD", else: "UNKNOWN BUILD"
config :oli,
  ecto_repos: [Oli.Repo],
  build: %{
    version: Mix.Project.config[:version],
    sha: System.get_env("SHA", default_sha),
    date: DateTime.now!("Etc/UTC"),
    env: Mix.env,
  },
  local_activity_manifests: Path.wildcard(File.cwd! <> "/assets/src/components/activities/*/manifest.json")
    |> Enum.map(&File.read!/1),
  email_from_name: System.get_env("EMAIL_FROM_NAME", "OLI Torus"),
  email_from_address: System.get_env("EMAIL_FROM_ADDRESS", "admin@example.edu"),
  email_reply_to: System.get_env("EMAIL_REPLY_TO", "admin@example.edu")

# Configures the endpoint
config :oli, OliWeb.Endpoint,
  live_view: [signing_salt: System.get_env("LIVE_VIEW_SALT", "LIVE_VIEW_SALT")],
  url: [host: "localhost"],
  secret_key_base: "GE9cpXBwVXNaplyUCYbIWqERmC/OlcR5iVMwLX9/W7gzQRxkD1ETjda9E0jW/BW1",
  render_errors: [view: OliWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: Oli.PubSub

# Configure reCAPTCHA
config :oli, :recaptcha,
  verify_url: "https://www.google.com/recaptcha/api/siteverify",
  timeout: 5000,
  site_key: System.get_env("RECAPTCHA_SITE_KEY"),
  secret: System.get_env("RECAPTCHA_PRIVATE_KEY")

# Configure help
config :oli, :help,
  dispatcher: Oli.Help.Providers.FreshdeskHelp

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :oli, :pow,
  repo: Oli.Repo,
  user: Oli.Accounts.Author,
  current_user_assigns_key: :current_author,
  session_key: "author_auth",
  web_module: OliWeb,
  routes_backend: OliWeb.Pow.AuthorRoutes,
  plug: Pow.Plug.Session,
  extensions: [PowResetPassword, PowEmailConfirmation, PowPersistentSession, PowInvitation],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
  mailer_backend: OliWeb.Pow.Mailer,
  web_mailer_module: OliWeb,
  pow_assent: [
    user_identities_context: OliWeb.Pow.UserIdentities,
    providers: [
      google: [
        client_id: System.get_env("GOOGLE_CLIENT_ID"),
        client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
        strategy: Assent.Strategy.Google,
        authorization_params: [
          scope: "email profile"
        ],
        session_params: ["type"]
      ],
      github: [
        client_id: System.get_env("GITHUB_CLIENT_ID"),
        client_secret: System.get_env("GITHUB_CLIENT_SECRET"),
        strategy: Assent.Strategy.Github,
        authorization_params: [
          scope: "read:user user:email"
        ],
        session_params: ["type"]
      ]
    ]
  ]

if Mix.env == :dev do
  config :mix_test_watch,
    clear: true
end

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
