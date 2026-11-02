Application.ensure_all_started(:ex_machina)
ExUnit.start(exclude: [:skip, :nightly], capture_log: true)

unless Oli.PythonRunner.available?() do
  ExUnit.configure(exclude: [:skip_if_no_python])
end

# Audit events need a partition for every inserted_at a test can produce, regardless of when the
# test database was migrated.
{:ok, _} = Oli.Auditing.Partitions.ensure_through(Date.shift(Date.utc_today(), year: 2))

Ecto.Adapters.SQL.Sandbox.mode(Oli.Repo, :manual)
