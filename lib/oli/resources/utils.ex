defmodule Oli.Resources.Utils do

  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType
  alias Oli.Resources.Page
  alias Oli.Resources.Container
  alias Oli.Resources.Objective
  alias Oli.Resources.Activity

  def to_revision(%Revision{} = revision), do: revision

  def to_revision(%Activity{} = wrapper) do
    %Revision{
      id: wrapper.id,
      title: wrapper.title,
      slug: wrapper.slug,
      deleted: wrapper.deleted,
      content: wrapper.content,
      children: [],
      graded: false,
      time_limit: wrapper.time_limit,
      recommended_attempts: wrapper.recommended_attempts,
      max_attempts: wrapper.max_attempts,
      scoring_strategy: wrapper.scoring_strategy,
      objectives: wrapper.objectives,
      resource_id: wrapper.resource_id,
      resource_type_id: wrapper.resource_type_id,
      author_id: wrapper.author_id,
      previous_revision_id: wrapper.previous_revision_id,
      activity_type_id: wrapper.activity_type_id,
      primary_resource_id: wrapper.primary_resource_id,
      inserted_at: wrapper.inserted_at,
      updated_at: wrapper.updated_at
    }
  end

  def to_revision(%Page{} = wrapper) do
    %Revision{
      id: wrapper.id,
      title: wrapper.title,
      slug: wrapper.slug,
      deleted: wrapper.deleted,
      content: wrapper.content,
      children: [],
      graded: wrapper.graded,
      time_limit: wrapper.time_limit,
      recommended_attempts: wrapper.recommended_attempts,
      max_attempts: wrapper.max_attempts,
      scoring_strategy: wrapper.scoring_strategy,
      objectives: %{ "attached" => wrapper.objectives },
      resource_id: wrapper.resource_id,
      resource_type_id: wrapper.resource_type_id,
      author_id: wrapper.author_id,
      previous_revision_id: wrapper.previous_revision_id,
      primary_resource_id: nil,
      activity_type_id: nil,
      inserted_at: wrapper.inserted_at,
      updated_at: wrapper.updated_at
    }
  end

  def to_revision(%Container{} = wrapper) do
    %Revision{
      id: wrapper.id,
      title: wrapper.title,
      slug: wrapper.slug,
      deleted: wrapper.deleted,
      content: %{},
      children: wrapper.children,
      graded: false,
      time_limit: nil,
      recommended_attempts: nil,
      max_attempts: nil,
      scoring_strategy: nil,
      objectives: wrapper.objectives,
      resource_id: wrapper.resource_id,
      resource_type_id: wrapper.resource_type_id,
      author_id: wrapper.author_id,
      previous_revision_id: wrapper.previous_revision_id,
      activity_type_id: nil,
      primary_resource_id: nil,
      inserted_at: wrapper.inserted_at,
      updated_at: wrapper.updated_at
    }
  end

  def to_revision(%Objective{} = wrapper) do
    %Revision{
      id: wrapper.id,
      title: wrapper.title,
      slug: wrapper.slug,
      deleted: wrapper.deleted,
      content: %{},
      children: wrapper.children,
      graded: false,
      time_limit: nil,
      recommended_attempts: nil,
      max_attempts: nil,
      scoring_strategy: nil,
      objectives: %{},
      resource_id: wrapper.resource_id,
      resource_type_id: wrapper.resource_type_id,
      author_id: wrapper.author_id,
      previous_revision_id: wrapper.previous_revision_id,
      primary_resource_id: nil,
      activity_type_id: nil,
      inserted_at: wrapper.inserted_at,
      updated_at: wrapper.updated_at
    }
  end

  def to_wrapper(%Revision{resource_type_id: resource_type_id} = revision) do

    case ResourceType.get_type_by_id(resource_type_id) do
      :page -> Page.from_revision(revision)
      :container -> Container.from_revision(revision)
      :activity -> Activity.from_revision(revision)
      :objective -> Objective.from_revision(revision)
    end

  end

  def to_wrapper(revisions) when is_list(revisions) do
    Enum.map(revisions, &to_wrapper/1)
  end

end
