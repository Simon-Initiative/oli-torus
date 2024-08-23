Application.ensure_all_started(:ex_machina)
ExUnit.start(exclude: [:skip])
Ecto.Adapters.SQL.Sandbox.mode(Oli.Repo, :manual)
