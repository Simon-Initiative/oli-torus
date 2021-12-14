defmodule Oli.Lti_1p3.Tool.Deployment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_1p3_deployments" do
    # deployment_id here is not a foreign key but the deployment identifier
    # associated with the lti connection
    field :deployment_id, :string

    belongs_to :registration, Oli.Lti_1p3.Tool.Registration

    belongs_to :institution, Oli.Institutions.Institution

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(deployment, attrs \\ %{}) do
    deployment
    |> cast(attrs, [:deployment_id, :registration_id, :institution_id])
    |> validate_required([:deployment_id, :registration_id, :institution_id])
  end
end
