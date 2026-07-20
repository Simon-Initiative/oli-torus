defmodule Oli.Delivery.Remix.Telemetry do
  @moduledoc false

  @source_selected [:oli, :delivery, :remix, :source_selected]
  @add_materials [:oli, :delivery, :remix, :add_materials]

  def source_selected(source_type) when source_type in [:project, :product] do
    safe_execute(@source_selected, %{count: 1}, %{source_type: source_type})
  end

  def add_materials(selection_count, source_types, outcome)
      when is_integer(selection_count) and selection_count >= 0 and
             outcome in [
               :ok,
               :shared_project_resources,
               :selected_projects_share_resources,
               :unavailable_publication,
               :unavailable_source
             ] do
    safe_execute(@add_materials, %{selection_count: selection_count}, %{
      source_types: source_types |> Enum.uniq() |> Enum.sort(),
      outcome: outcome
    })
  end

  defp safe_execute(event, measurements, metadata) do
    Task.Supervisor.start_child(Oli.TaskSupervisor, fn ->
      :telemetry.execute(event, measurements, metadata)
    end)

    :ok
  rescue
    _ -> :ok
  end
end
