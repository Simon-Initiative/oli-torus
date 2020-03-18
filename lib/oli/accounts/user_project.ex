defmodule Oli.Accounts.AuthorProject do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "authors_projects" do
    timestamps()
    belongs_to :author, Oli.Accounts.Author
    belongs_to :project, Oli.Authoring.Project
    belongs_to :project_role, Oli.Accounts.ProjectRole
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:author_id, :project_id, :project_role_id])
    |> validate_required([:author_id, :project_id, :project_role_id])
  end
end
