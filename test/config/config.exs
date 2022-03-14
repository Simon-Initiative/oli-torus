import Config

config :oli, payment_provider: "none"

config :oli, :age_verification, is_enabled: "false"

config :oli, :auth_providers,
  google_client_id: System.get_env("GOOGLE_CLIENT_ID", ""),
  google_client_secret: System.get_env("GOOGLE_CLIENT_SECRET", ""),
  github_client_id: System.get_env("GITHUB_CLIENT_ID", ""),
  github_client_secret: System.get_env("GITHUB_CLIENT_SECRET", "")
