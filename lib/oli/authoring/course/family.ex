defmodule Oli.Authoring.Course.Family do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Utils.Slug

  @derive {Phoenix.Param, key: :slug}
  schema "families" do
    field :description, :string
    field :slug, :string
    field :title, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(family, attrs \\ %{}) do
    family
    |> cast(attrs, [:title, :slug, :description])
    |> validate_required([:title])
    |> Slug.update_never("families")
  end

end
