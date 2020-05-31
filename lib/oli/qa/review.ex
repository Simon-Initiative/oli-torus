defmodule Oli.Qa.Review do
  use Ecto.Schema
  import Ecto.Changeset

  schema "qa_reviews" do
    belongs_to :project, Oli.Authoring.Course.Project
    belongs_to :revision, Oli.Resources.Revision
    field :type, :string
    field :subtype, :string
    field :content, :map
    field :requires_fix, :boolean, default: false
    field :is_dismissed, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(struct, attrs \\ %{}) do
    struct
    |> cast(attrs, ~w(project_id revision_id content requires_fix is_dismissed type subtype)a)
    |> validate_required(~w(project_id type)a)
  end

end
