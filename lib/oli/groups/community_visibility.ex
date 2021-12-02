defmodule Oli.Groups.CommunityVisibility do
  use Ecto.Schema
  import Ecto.Changeset

  schema "communities_visibilities" do
    belongs_to :community, Oli.Groups.Community
    belongs_to :project, Oli.Authoring.Course.Project
    belongs_to :section, Oli.Delivery.Sections.Section

    field :unique_type, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(community_visibility, attrs \\ %{}) do
    community_visibility
    |> cast(attrs, [:community_id, :project_id, :section_id])
    |> validate_required([:community_id])
    |> unique_constraint([:community_id, :project_id], name: :index_community_project)
    |> unique_constraint([:community_id, :section_id], name: :index_community_section)
  end
end
