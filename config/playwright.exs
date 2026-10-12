import Config

# Shared by disposable PR servers and the durable nightly release. Secrets and
# service addresses belong in runtime.exs; compilation requires none of them.
config :oli,
  env: :playwright,
  enable_playwright_scenarios: true,
  enable_e2e_mailbox: true,
  recaptcha_module: Oli.Playwright.Recaptcha

config :oli, OliWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  code_reloader: false,
  debug_errors: false,
  check_origin: true,
  live_reload: nil,
  watchers: nil

config :phoenix_live_view, debug_heex_annotations: false, enable_expensive_runtime_checks: false
config :logger, level: :info
config :oli, Oli.Mailer, adapter: Swoosh.Adapters.Local
