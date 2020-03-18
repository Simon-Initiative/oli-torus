defmodule Oli.Authoring.PageWithPosition do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "pages_with_positions" do
    timestamps()
    belongs_to :project, Oli.Authoring.Project
    belongs_to :page, Oli.Authoring.Resource
    field :position, :integer
  end

  @doc false
  def changeset(page_with_position, attrs \\ %{}) do
    page_with_position
    |> cast(attrs, [
      :project,
      :page,
      :position
    ])
    |> validate_required([:project, :page, :position])
  end
end
