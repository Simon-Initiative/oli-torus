defmodule Oli.Activities.ActivityRegistration do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment

  schema "activity_registrations" do
    field :slug, :string
    field :authoring_script, :string
    field :delivery_script, :string
    field :description, :string
    field :authoring_element, :string
    field :delivery_element, :string
    field :icon, :string
    field :title, :string
    field :petite_label, :string
    field :allow_client_evaluation, :boolean, default: false
    field :globally_available, :boolean, default: false
    field :globally_visible, :boolean, default: true
    field :variables, {:array, :string}, default: []
    field :generates_report, :boolean, default: false

    field :deployment_id, :string, virtual: true
    field :project_status, Ecto.Enum, values: [:enabled, :disabled], virtual: true

    field :status, Ecto.Enum,
      values: LtiExternalToolActivityDeployment.status_values(),
      virtual: true

    # Optionally, this activity registration can be associated with an LTI deployment.
    # If an LTI deployment is associated, the activity is considered an LTI activity.
    has_one :lti_external_tool_activity_deployment,
            LtiExternalToolActivityDeployment

    many_to_many :projects, Oli.Authoring.Course.Project,
      join_through: Oli.Activities.ActivityRegistrationProject

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(registration, attrs) do
    registration
    |> cast(attrs, [
      :slug,
      :title,
      :petite_label,
      :icon,
      :description,
      :delivery_element,
      :authoring_element,
      :delivery_script,
      :authoring_script,
      :allow_client_evaluation,
      :generates_report,
      :globally_available,
      :globally_visible,
      :variables
    ])
    |> validate_required([
      :slug,
      :title,
      :petite_label,
      :icon,
      :description,
      :delivery_element,
      :authoring_element,
      :delivery_script,
      :authoring_script
    ])
    |> unique_constraint(:slug)
  end
end
