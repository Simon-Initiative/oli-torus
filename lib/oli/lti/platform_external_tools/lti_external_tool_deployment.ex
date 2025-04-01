defmodule Oli.Lti.PlatformExternalTools.LtiExternalToolDeployment do
  use Ecto.Schema
  import Ecto.Changeset

  # the primary key 'id' is the same as the LTI 1.3 deployment ID
  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "lti_external_tool_deployments" do
    belongs_to :platform_instance,
               Lti_1p3.DataProviders.EctoProvider.PlatformInstance,
               foreign_key: :platform_instance_id

    timestamps(type: :utc_datetime)
  end

  def changeset(lti_external_tool_deployment, attrs \\ %{}) do
    lti_external_tool_deployment
    |> cast(attrs, [:platform_instance_id])
    |> validate_required([:platform_instance_id])
  end
end
