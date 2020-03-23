defmodule Oli.Sections.Section do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sections" do
    field :end_date, :date
    field :open_and_free, :boolean, default: false
    field :registration_open, :boolean, default: false
    field :start_date, :date
    field :time_zone, :string
    field :title, :string

    belongs_to :institution, Oli.Accounts.Institution
    belongs_to :project, Oli.Course.Project
    belongs_to :publication, Oli.Publishing.Publication

    timestamps()
  end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [:title, :start_date, :end_date, :time_zone, :open_and_free, :registration_open])
    |> validate_required([:title, :start_date, :end_date, :time_zone, :open_and_free, :registration_open, :institution, :project, :publication])
  end
end
