defmodule Oli.GenAI.RuntimeSupervisor do
  @moduledoc "Supervises observe-only Provider monitoring and node-local transport reconciliation."
  use Supervisor

  @doc "Starts the isolated runtime infrastructure."
  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    max_probes = Application.get_env(:oli, :genai_health, []) |> Keyword.get(:max_probes, 4)

    Supervisor.init(
      [
        {Task.Supervisor, name: Oli.GenAI.HealthTasks, max_children: max_probes},
        Oli.GenAI.PoolManager,
        {Oli.GenAI.Runtime, task_supervisor: Oli.GenAI.HealthTasks}
      ],
      strategy: :one_for_all
    )
  end
end
