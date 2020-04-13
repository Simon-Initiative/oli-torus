defmodule Oli.Authoring.Authors.AuthorProject do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "authors_projects" do
    timestamps()
    field :author_id, :integer, primary_key: true
    field :project_id, :integer, primary_key: true
    belongs_to :project_role, Oli.Authoring.Authors.ProjectRole
  end

  @doc false
  def changeset(author_project \\ %Oli.Authoring.Authors.AuthorProject{}, attrs \\ %{}) do
    author_project
    |> cast(attrs, [:author_id, :project_id, :project_role_id])
    |> validate_required([:author_id, :project_id, :project_role_id])
    |> unique_constraint(:author_id, name: :index_author_project)
  end
end
