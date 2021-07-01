defmodule Oli.Delivery.Sections.SectionsProjectsPublications do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Sections.Section
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing.Publication

  @primary_key false
  schema "sections_projects_publications" do
    belongs_to :section, Section
    belongs_to :project, Project
    belongs_to :publication, Publication

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_section, attrs \\ %{}) do
    user_section
    |> cast(attrs, [:section_id, :project_id, :publication_id])
    |> validate_required([:section_id, :project_id, :publication_id])
  end
end
