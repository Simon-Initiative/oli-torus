defmodule Oli.Delivery.Sections.Section do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sections" do
    field :end_date, :date
    field :registration_open, :boolean, default: false
    field :start_date, :date
    field :time_zone, :string
    field :title, :string
    field :context_id, :string

    # these fields are set on section creation for LTI grade passback
    field :lti_lineitems_url, :string
    field :lti_lineitems_token, :string

    # these fields are available to be set by an LMS adapter for alternative
    # grade passback or custom API actions
    field :api_url, :string
    field :api_token, :string
    field :api_id, :string

    belongs_to :institution, Oli.Accounts.Institution
    belongs_to :project, Oli.Authoring.Course.Project
    belongs_to :publication, Oli.Publishing.Publication

    has_many :enrollments, Oli.Delivery.Sections.Enrollment

    timestamps(type: :utc_datetime)

end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [:title, :start_date, :end_date, :time_zone, :registration_open, :context_id, :lti_lineitems_url, :api_url, :api_token, :api_id, :institution_id, :project_id, :publication_id])
    |> validate_required([:title, :time_zone, :registration_open, :context_id, :institution_id, :project_id, :publication_id])
  end
end
