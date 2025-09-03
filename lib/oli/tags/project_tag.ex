defmodule Oli.Tags.ProjectTag do
  @moduledoc """
  Join table schema for the many-to-many relationship between projects and tags.
  """

  use Ecto.Schema

  @primary_key false
  schema "project_tags" do
    belongs_to :project, Oli.Authoring.Course.Project, primary_key: true
    belongs_to :tag, Oli.Tags.Tag, primary_key: true
    timestamps(type: :utc_datetime)
  end
end
