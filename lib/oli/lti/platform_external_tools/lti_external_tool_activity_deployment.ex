defmodule Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment do
  use Ecto.Schema
  import Ecto.Changeset

  # the primary key 'id' is the same as the LTI 1.3 deployment ID
  @primary_key {:deployment_id, Ecto.UUID, autogenerate: true}

  schema "lti_external_tool_activity_deployments" do
    belongs_to :activity_registration,
               Oli.Activities.ActivityRegistration,
               foreign_key: :activity_registration_id

    belongs_to :platform_instance,
               Lti_1p3.DataProviders.EctoProvider.PlatformInstance,
               foreign_key: :platform_instance_id

    field :status, Ecto.Enum, values: [:enabled, :disabled, :deleted], default: :enabled

    timestamps(type: :utc_datetime)
  end

  def changeset(lti_external_tool_deployment, attrs \\ %{}) do
    lti_external_tool_deployment
    |> cast(attrs, [:activity_registration_id, :platform_instance_id, :status])
    |> validate_required([:activity_registration_id, :platform_instance_id])
    |> validate_inclusion(:status, Ecto.Enum.values(__MODULE__, :status))
  end
end
