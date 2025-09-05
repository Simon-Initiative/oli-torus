defmodule Oli.Tags.ProjectTag do
  @moduledoc """
  Join table schema for the many-to-many relationship between projects and tags.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "project_tags" do
    belongs_to :project, Oli.Authoring.Course.Project, primary_key: true
    belongs_to :tag, Oli.Tags.Tag, primary_key: true
    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a project tag association.
  """
  def changeset(project_tag, attrs \\ %{}) do
    project_tag
    |> cast(attrs, [:project_id, :tag_id])
    |> validate_required([:project_id, :tag_id])
    |> unique_constraint([:project_id, :tag_id], name: :project_tags_pkey)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:tag_id)
  end
end
