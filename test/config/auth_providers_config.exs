import Config

config :oli, :auth_providers,
  google_client_id: System.get_env("GOOGLE_CLIENT_ID", "client_id"),
  google_client_secret: System.get_env("GOOGLE_CLIENT_SECRET", "client_secret"),
  github_client_id: System.get_env("GITHUB_CLIENT_ID", "client_id"),
  github_client_secret: System.get_env("GITHUB_CLIENT_SECRET", "client_secret")
