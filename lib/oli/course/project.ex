defmodule Oli.Course.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :description, :string
    field :slug, :string
    field :title, :string
    field :version, :string

    belongs_to :parent_project, Oli.Course.Project, foreign_key: :project_id
    belongs_to :family, Oli.Course.Family

    timestamps()
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:title, :slug, :description, :version])
    |> validate_required([:title, :slug, :description, :version])
    |> unique_constraint(:slug)
  end
end
