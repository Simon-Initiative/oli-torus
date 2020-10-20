defmodule Oli.Lti_1p3.Deployment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_1p3_deployments" do
    field :deployment_id, :string

    belongs_to :registration, Oli.Lti_1p3.Registration
    has_many :sections, Oli.Delivery.Sections.Section, foreign_key: :lti_1p3_deployment_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(deployment, attrs \\ %{}) do
    deployment
    |> cast(attrs, [:deployment_id, :registration_id])
    |> validate_required([:deployment_id, :registration_id])
  end
end
