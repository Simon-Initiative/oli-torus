import Config

# Preview is a production-shaped release environment with an explicit QA safety
# delta. Keep this file standalone so production configuration changes do not
# implicitly alter preview behavior.
config :oli,
  env: :preview,
  preview_qa_tools: [preview_build?: true]

config :oli, OliWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info

# Preview email must remain local even when PREVIEW_QA_TOOLS_ENABLED is disabled.
config :oli, Oli.Mailer, adapter: Swoosh.Adapters.Local

config :appsignal, :config, ignore_actions: ["OliWeb.HealthController#index"]
