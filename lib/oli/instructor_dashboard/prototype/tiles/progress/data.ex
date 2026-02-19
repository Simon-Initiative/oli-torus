defmodule Oli.InstructorDashboard.Prototype.Tiles.Progress.Data do
  @moduledoc """
  Non-UI projection logic for the Progress tile.
  """

  alias Oli.InstructorDashboard.Prototype.Oracles
  alias Oli.InstructorDashboard.Prototype.Snapshot
  alias Oli.InstructorDashboard.Prototype.Scope

  def build(%Snapshot{} = snapshot) do
    with {:ok, progress_payload} <- Snapshot.fetch_oracle(snapshot, Oracles.Progress),
         {:ok, contents_payload} <- Snapshot.fetch_oracle(snapshot, Oracles.Contents) do
      {:ok, build_projection(snapshot.scope, progress_payload, contents_payload)}
    end
  end

  defp build_projection(%Scope{} = scope, progress_payload, contents_payload) do
    axis_type = axis_container_type(scope)
    threshold = Map.get(scope.filters, :completion_threshold, 80)
    containers = containers_for_axis(scope, contents_payload, axis_type)

    progress_by_container =
      progress_payload
      |> Map.get(:by_container, %{})
      |> Map.get(axis_type, %{})

    series =
      Enum.map(containers, fn container ->
        student_progress = Map.get(progress_by_container, container.id, %{})
        total = map_size(student_progress)

        count =
          Enum.count(student_progress, fn {_student_id, percent} ->
            percent >= threshold
          end)

        %{
          container_id: container.id,
          container_title: container.title,
          count: count,
          total: total,
          percent: percent(count, total)
        }
      end)

    %{
      axis_container_type: axis_type,
      completion_threshold: threshold,
      total_students: length(Map.get(progress_payload, :student_ids, [])),
      series: series
    }
  end

  defp axis_container_type(%Scope{container_type: :course}), do: :unit
  defp axis_container_type(%Scope{container_type: :unit}), do: :module
  defp axis_container_type(%Scope{container_type: :module}), do: :module

  defp containers_for_axis(%Scope{}, %{units: units}, :unit), do: units

  defp containers_for_axis(%Scope{} = scope, %{units: units}, :module) do
    case scope.container_type do
      :unit ->
        unit = Enum.find(units, fn unit -> unit.id == scope.container_id end)
        Map.get(unit || %{}, :modules, [])

      :module ->
        units
        |> Enum.flat_map(& &1.modules)
        |> Enum.filter(fn module -> module.id == scope.container_id end)

      :course ->
        units
        |> Enum.flat_map(& &1.modules)
    end
  end

  defp percent(_count, 0), do: 0

  defp percent(count, total) do
    count
    |> Kernel./(total)
    |> Kernel.*(100)
    |> Float.round(1)
  end
end
