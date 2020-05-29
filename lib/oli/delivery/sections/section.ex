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
    field :lti_lineitems_url, :string
    field :lti_lineitems_token, :string

    belongs_to :institution, Oli.Accounts.Institution
    belongs_to :project, Oli.Authoring.Course.Project
    belongs_to :publication, Oli.Publishing.Publication

    has_many :enrollments, Oli.Delivery.Sections.Enrollment

    timestamps(type: :utc_datetime)

end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [:title, :start_date, :end_date, :time_zone, :registration_open, :context_id, :lti_lineitems_url, :institution_id, :project_id, :publication_id])
    |> validate_required([:title, :time_zone, :registration_open, :context_id, :institution_id, :project_id, :publication_id])
  end
end
