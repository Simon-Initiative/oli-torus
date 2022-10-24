defmodule Oli.Authoring.Editing.Blueprint do
  use Ecto.Schema
  import Ecto.Changeset

  schema "blueprints" do
    timestamps(type: :utc_datetime)
    field :name, :string
    field :description, :string
    field :icon, :string
    field :content, :map, default: %{}
  end

  def changeset(blueprint, attrs \\ %{}) do
    blueprint
    |> cast(attrs, [
      :name,
      :description,
      :content,
      :icon
    ])
    |> validate_required([:name, :description, :content, :icon])
  end

  def list_blueprints do
    Oli.Repo.all(Oli.Authoring.Editing.Blueprint)
  end
end
