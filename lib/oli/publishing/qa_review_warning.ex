defmodule Oli.Publishing.QaReviewWarning do
  use Ecto.Schema
  import Ecto.Changeset

  schema "qa_review_warnings" do
    belongs_to :project, Oli.Authoring.Course.Project
    belongs_to :resource, Oli.Resources.Resource
    field :description, :string
    field :requires_fix, :boolean, default: false
    field :is_dismissed, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(struct, attrs \\ %{}) do
    struct
    |> cast(attrs, ~w(project_id resource_id description requires_fix is_dismissed)a)
    |> validate_required(~w(project_id description)a)
  end

end
