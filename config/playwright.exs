import Config

import_config "dev.exs"

# This environment is reserved for the ephemeral Torus instance used by the
# credential-account Playwright suite. It must never be used for a persistent
# staging or production deployment.
config :oli,
  env: :playwright,
  enable_playwright_scenarios: true,
  playwright_scenario_token: System.fetch_env!("PLAYWRIGHT_SCENARIO_TOKEN"),
  recaptcha_module: Oli.Playwright.Recaptcha

config :oli, Oli.Repo, database: System.get_env("DB_NAME", "oli_playwright")

config :oli, OliWeb.Endpoint,
  code_reloader: false,
  live_reload: []

config :oli, Oli.Mailer, adapter: Swoosh.Adapters.Local
