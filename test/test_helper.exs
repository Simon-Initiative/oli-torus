Application.ensure_all_started(:ex_machina)
ExUnit.start(exclude: [:skip])

unless Oli.PythonRunner.available?() do
  ExUnit.configure(exclude: [:skip_if_no_python])
end

Ecto.Adapters.SQL.Sandbox.mode(Oli.Repo, :manual)
