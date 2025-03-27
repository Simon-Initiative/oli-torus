Application.ensure_all_started(:ex_machina)

ExUnit.start(
  exclude: [:skip],
  failures_manifest_path: "/Users/martin/work/oli-torus/failures_manifest.txt"
)

Ecto.Adapters.SQL.Sandbox.mode(Oli.Repo, :manual)
