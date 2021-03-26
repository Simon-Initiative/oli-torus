defmodule Oli.Activities.ActivityRegistrationProject do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "activity_registration_projects" do
    timestamps(type: :utc_datetime)
    field :activity_registration_id, :integer, primary_key: true
    field :project_id, :integer, primary_key: true
  end

  @doc false
  def changeset(author_project, attrs \\ %{}) do
    author_project
    |> cast(attrs, [:activity_registration_id, :project_id])
    |> validate_required([:activity_registration_id, :project_id])
    |> unique_constraint(:activity_registration_id, name: :index_activity_registration_project)
  end
end
