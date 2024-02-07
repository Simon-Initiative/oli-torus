defmodule Oli.Resources.ResourceType do
  use Ecto.Schema
  import Ecto.Changeset

  @resource_types ~w(page container activity objective secondary tag bibentry alternatives)
  @resource_types_count Enum.count(@resource_types)

  for {resource_type, id} <- Enum.with_index(@resource_types, 1) do
    def get_id_by_type(unquote(resource_type)), do: unquote(id)

    def get_type_by_id(unquote(id)) when unquote(id) in 1..@resource_types_count,
      do: unquote(resource_type)

    def unquote(String.to_atom("id_for_#{resource_type}"))(), do: unquote(id)

    def unquote(String.to_atom("is_#{resource_type}"))(revision),
      do: get_type_by_id(revision.resource_type_id) == unquote(resource_type)
  end

  def get_types(),
    do: Enum.with_index(@resource_types, fn type, index -> %{id: index + 1, type: type} end)

  def is_non_adaptive_page(revision),
    do: is_page(revision) and !is_adaptive_page(revision)

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
