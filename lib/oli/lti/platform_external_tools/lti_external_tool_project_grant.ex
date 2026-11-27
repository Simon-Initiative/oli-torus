defmodule Oli.Lti.PlatformExternalTools.LtiExternalToolProjectGrant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_external_tool_project_grants" do
    belongs_to :deployment,
               Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment,
               foreign_key: :deployment_id,
               references: :deployment_id,
               type: Ecto.UUID

    belongs_to :project, Oli.Authoring.Course.Project

    timestamps(type: :utc_datetime)
  end

  @doc """
  Casts `deployment_id` and `project_id`, both required, and maps a missing deployment or project and a
  duplicate grant for the same pair to changeset errors.
  """
  def changeset(grant, attrs \\ %{}) do
    grant
    |> cast(attrs, [:deployment_id, :project_id])
    |> validate_required([:deployment_id, :project_id])
    |> foreign_key_constraint(:deployment_id)
    |> foreign_key_constraint(:project_id)
    |> unique_constraint([:deployment_id, :project_id])
  end
end
