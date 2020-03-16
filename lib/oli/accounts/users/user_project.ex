defmodule Oli.Accounts.UserProject do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "users_projects" do
    timestamps()
    belongs_to :user, Oli.Accounts.User
    belongs_to :project, Oli.Authoring.Project
    belongs_to :project_role, Oli.Accounts.ProjectRole
  end

  @doc false
  def changeset(user_project, attrs) do
    user_project
    |> cast(attrs, [:user_id, :project_id, :project_role_id])
    |> validate_required([:user_id, :project_id, :project_role_id])
  end
end
