defmodule Oli.Activities.ActivityRegistrationProject do
  @moduledoc """
  This schema is used to join activity registrations to projects.
  Activities listed here were added by an author to the project.
  Once added, authors can enable or disable activities at the project level.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "activity_registration_projects" do
    timestamps(type: :utc_datetime)
    field :activity_registration_id, :integer, primary_key: true
    field :project_id, :integer, primary_key: true
    field :status, Ecto.Enum, values: [:enabled, :disabled], default: :enabled
  end

  @doc false
  def changeset(author_project, attrs \\ %{}) do
    author_project
    |> cast(attrs, [:activity_registration_id, :project_id, :status])
    |> validate_required([:activity_registration_id, :project_id, :status])
    |> unique_constraint(:activity_registration_id, name: :index_activity_registration_project)
    |> validate_inclusion(:status, Ecto.Enum.values(__MODULE__, :status))
  end
end
