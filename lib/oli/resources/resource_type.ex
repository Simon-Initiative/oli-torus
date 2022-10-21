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
    %{id: 6, type: "tag"},
    %{id: 7, type: "bibentry"},
    %{id: 8, type: "alternatives"}
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
  def get_type_by_id(7), do: Map.get(@by_id, 7)
  def get_type_by_id(8), do: Map.get(@by_id, 8)

  def get_id_by_type("page"), do: Map.get(@by_type, "page")
  def get_id_by_type("container"), do: Map.get(@by_type, "container")
  def get_id_by_type("activity"), do: Map.get(@by_type, "activity")
  def get_id_by_type("objective"), do: Map.get(@by_type, "objective")
  def get_id_by_type("secondary"), do: Map.get(@by_type, "secondary")
  def get_id_by_type("tag"), do: Map.get(@by_type, "tag")
  def get_id_by_type("bibentry"), do: Map.get(@by_type, "bibentry")
  def get_id_by_type("alternatives"), do: Map.get(@by_type, "alternatives")

  defp is_type(revision, type), do: get_type_by_id(revision.resource_type_id) == type
  def is_page(revision), do: is_type(revision, "page")
  def is_container(revision), do: is_type(revision, "container")
  def is_activity(revision), do: is_type(revision, "activity")
  def is_objective(revision), do: is_type(revision, "objective")
  def is_secondary(revision), do: is_type(revision, "secondary")
  def is_tag(revision), do: is_type(revision, "tag")
  def is_bibentry(revision), do: is_type(revision, "bibentry")
  def is_alternatives(revision), do: is_type(revision, "alternatives")

  def is_non_adaptive_page(revision),
    do: is_type(revision, "page") and !is_adaptive_page(revision)

  def is_adaptive_page(%{content: %{"advancedAuthoring" => true}}), do: true
  def is_adaptive_page(_), do: false

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
