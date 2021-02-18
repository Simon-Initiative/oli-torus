defmodule Oli.Authoring.Course.ProjectVisibility do
  use Ecto.Schema
  import Ecto.Changeset

  schema "project_visibilities" do
    field :project_id, :integer
    field :author_id, :integer
    field :institution_id, :integer

    timestamps(type: :utc_datetime)
  end

  @spec changeset(
          {map, map} | %{:__struct__ => atom | %{__changeset__: map}, optional(atom) => any},
          :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}
        ) :: Ecto.Changeset.t()
  @doc false
  def changeset(project_visibility, attrs) do
    project_visibility
    |> cast(attrs, [:project_id, :author_id, :institution_id])
    |> validate_required([:project_id])
  end

end
