defmodule Oli.InstructorDashboard.Prototype.Oracles.Contents do
  @moduledoc """
  Prototype contents oracle returning unit/module structure.
  """

  @behaviour Oli.InstructorDashboard.Prototype.Oracle

  alias Oli.InstructorDashboard.Prototype.MockData
  alias Oli.InstructorDashboard.Prototype.Scope

  @impl true
  def key, do: :contents

  @impl true
  def load(%Scope{} = scope, _opts) do
    {:ok,
     %{
       course_title: "Biology 101",
       items: direct_items(scope),
       units: MockData.units()
     }}
  end

  defp direct_items(%Scope{container_type: :course}) do
    Enum.map(MockData.direct_children(:course, nil), fn unit ->
      %{
        resource_id: unit.id,
        resource_type_id: :unit,
        title: unit.title
      }
    end)
  end

  defp direct_items(%Scope{container_type: container_type, container_id: container_id}) do
    container_type
    |> MockData.direct_children(container_id)
    |> Enum.map(fn item ->
      %{
        resource_id: item.id,
        resource_type_id: item.resource_type,
        title: item.title
      }
    end)
  end
end
