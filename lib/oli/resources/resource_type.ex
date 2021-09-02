defmodule Oli.Resources.ResourceType do
  use Ecto.Schema
  import Ecto.Changeset

  # It would be great to encapsulate all of this into a macro.

  @types [
    %{id: 1, type: "page"},
    %{id: 2, type: "container"},
    %{id: 3, type: "activity"},
    %{id: 4, type: "objective"},
    %{id: 5, type: "secondary"},
    %{id: 6, type: "tag"}
  ]
  @by_id Enum.reduce(@types, %{}, fn %{id: id, type: t}, m -> Map.put(m, id, t) end)
  @by_type Enum.reduce(@types, %{}, fn %{id: id, type: t}, m -> Map.put(m, t, id) end)

  def get_types, do: @types

  # By defining these functions like this we get a level of compile time
  # safety since a client could not do something like call get_id_by_type("contaner")
  def get_type_by_id(1), do: Map.get(@by_id, 1)
  def get_type_by_id(2), do: Map.get(@by_id, 2)
  def get_type_by_id(3), do: Map.get(@by_id, 3)
  def get_type_by_id(4), do: Map.get(@by_id, 4)
  def get_type_by_id(5), do: Map.get(@by_id, 5)
  def get_type_by_id(6), do: Map.get(@by_id, 6)

  def get_id_by_type("page"), do: Map.get(@by_type, "page")
  def get_id_by_type("container"), do: Map.get(@by_type, "container")
  def get_id_by_type("activity"), do: Map.get(@by_type, "activity")
  def get_id_by_type("objective"), do: Map.get(@by_type, "objective")
  def get_id_by_type("secondary"), do: Map.get(@by_type, "secondary")
  def get_id_by_type("tag"), do: Map.get(@by_type, "tag")

  schema "resource_types" do
    field :type, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(resource_type, attrs) do
    resource_type
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end
end
