import Config

import_config "dev.exs"

# This environment is reserved for an ephemeral Torus instance used by CI E2E
# suites. It must never be used for a persistent staging or production deployment.
config :oli,
  env: :ci_e2e,
  enable_playwright_scenarios: true,
  enable_e2e_mailbox: true,
  playwright_scenario_token: System.fetch_env!("PLAYWRIGHT_SCENARIO_TOKEN"),
  recaptcha_module: Oli.Playwright.Recaptcha

config :oli, Oli.Repo, database: System.get_env("DB_NAME", "oli_ci_e2e")

config :oli, OliWeb.Endpoint,
  code_reloader: false,
  live_reload: [],
  watchers: []

config :oli, Oli.Mailer, adapter: Swoosh.Adapters.Local
