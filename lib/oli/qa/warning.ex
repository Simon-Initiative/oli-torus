defmodule Oli.Qa.Warning do
  use Ecto.Schema
  import Ecto.Changeset

  schema "warnings" do
    belongs_to :review, Oli.Qa.Review
    belongs_to :revision, Oli.Resources.Revision
    field :subtype, :string
    field :content, :map
    field :requires_fix, :boolean, default: false
    field :is_dismissed, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(struct, attrs \\ %{}) do
    struct
    |> cast(attrs, ~w(review_id revision_id subtype content requires_fix is_dismissed)a)
    |> validate_required(~w(review_id subtype)a)
  end
end
