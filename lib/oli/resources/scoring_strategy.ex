defmodule Oli.Resources.ScoringStrategy do
  use Ecto.Schema
  import Ecto.Changeset

  # It would be great to encapsulate all of this into a macro.

  @types [%{id: 1, type: "average"}, %{id: 2, type: "best"}, %{id: 3, type: "most_recent"}, %{id: 4, type: "total"}]
  @by_id Enum.reduce(@types, %{}, fn %{id: id, type: t}, m -> Map.put(m, id, t) end)
  @by_type Enum.reduce(@types, %{}, fn %{id: id, type: t}, m -> Map.put(m, t, id) end)

  def get_types, do: @types

  # By defining these functions like this we get a level of compile time
  # safety since a client could not do something like call get_id_by_type("contaner")
  def get_type_by_id(1), do: Map.get(@by_id, 1)
  def get_type_by_id(2), do: Map.get(@by_id, 2)
  def get_type_by_id(3), do: Map.get(@by_id, 3)
  def get_type_by_id(4), do: Map.get(@by_id, 4)

  def get_id_by_type("average"), do: Map.get(@by_type, "average")
  def get_id_by_type("best"), do: Map.get(@by_type, "best")
  def get_id_by_type("most_recent"), do: Map.get(@by_type, "most_recent")
  def get_id_by_type("total"), do: Map.get(@by_type, "total")

  schema "scoring_strategies" do
    field :type, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(scoring_strategy, attrs) do
    scoring_strategy
    |> cast(attrs, [:type])
    |> validate_required([:type])
  end
end
