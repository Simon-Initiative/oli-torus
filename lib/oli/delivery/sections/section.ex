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

    # TODO: Remove when LTI 1.3 GS replaces canvas api for grade passback
    # these fields are used by canvas specific grade passback
    field :canvas_url, :string
    field :canvas_token, :string
    field :canvas_id, :string

    belongs_to :institution, Oli.Accounts.Institution
    belongs_to :project, Oli.Authoring.Course.Project
    belongs_to :publication, Oli.Publishing.Publication

    has_many :enrollments, Oli.Delivery.Sections.Enrollment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [:title, :start_date, :end_date, :time_zone, :registration_open, :context_id, :lti_lineitems_url, :lti_lineitems_token, :canvas_url, :canvas_token, :canvas_id, :institution_id, :project_id, :publication_id])
    |> validate_required([:title, :time_zone, :registration_open, :context_id, :institution_id, :project_id, :publication_id])
  end
end
