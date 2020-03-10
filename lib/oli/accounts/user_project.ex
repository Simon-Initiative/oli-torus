defmodule Oli.Accounts.UserProject do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "users_projects" do
    timestamps()
    belongs_to :user, Oli.Accounts.User
    belongs_to :project, Oli.Authoring.Project
    belongs_to :role, Oli.Accounts.Role
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:user_id, :project_id, :role_id])
    |> validate_required([:user_id, :project_id, :role_id])
  end
end
