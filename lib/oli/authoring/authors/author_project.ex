defmodule Oli.Authoring.Authors.AuthorProject do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "authors_projects" do
    timestamps(type: :utc_datetime)
    field :author_id, :integer, primary_key: true
    field :project_id, :integer, primary_key: true
    belongs_to :project_role, Oli.Authoring.Authors.ProjectRole

    field :status, Ecto.Enum,
      values: [:accepted, :pending_confirmation, :rejected],
      default: :accepted
  end

  @doc false
  def changeset(author_project, attrs \\ %{}) do
    author_project
    |> cast(attrs, [:author_id, :project_id, :project_role_id, :status])
    |> validate_required([:author_id, :project_id, :project_role_id])
    |> unique_constraint(:author_id, name: :index_author_project)
    |> validate_inclusion(:status, Ecto.Enum.values(__MODULE__, :status))
  end
end
