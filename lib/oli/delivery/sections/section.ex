defmodule Oli.Delivery.Sections.Section do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Utils.Slug

  schema "sections" do
    field :registration_open, :boolean, default: false
    field :start_date, :date
    field :end_date, :date
    field :time_zone, :string
    field :title, :string
    field :context_id, :string
    field :slug, :string
    field :open_and_free, :boolean, default: false

    belongs_to :lti_1p3_deployment, Lti_1p3.DataProviders.EctoProvider.Deployment, foreign_key: :lti_1p3_deployment_id

    belongs_to :institution, Oli.Institutions.Institution
    belongs_to :project, Oli.Authoring.Course.Project
    belongs_to :publication, Oli.Publishing.Publication

    has_many :enrollments, Oli.Delivery.Sections.Enrollment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [:title, :start_date, :end_date, :time_zone, :registration_open, :context_id, :slug, :lti_1p3_deployment_id, :institution_id, :project_id, :publication_id])
    |> validate_required([:title, :time_zone, :registration_open, :context_id, :institution_id, :project_id, :publication_id])
    |> Slug.update_never("sections")
  end
end
