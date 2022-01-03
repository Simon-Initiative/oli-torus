defmodule Oli.Groups.CommunityInstitution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "communities_institutions" do
    belongs_to :community, Oli.Groups.Community
    belongs_to :institution, Oli.Institutions.Institution

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(community_institution, attrs \\ %{}) do
    community_institution
    |> cast(attrs, [:community_id, :institution_id])
    |> validate_required([:community_id, :institution_id])
    |> unique_constraint([:community_id, :institution_id], name: :index_community_institution)
  end
end
