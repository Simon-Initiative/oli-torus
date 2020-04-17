defmodule Oli.Editing.ActivityEditor do
  @moduledoc """
  This module provides content editing facilities for activities.

  """

  import Oli.Editing.Utils
  alias Oli.Activities.ActivityRevision
  alias Oli.Publishing
  alias Oli.Activities
  alias Oli.Accounts.Author
  alias Oli.Course
  alias Oli.Repo

  @doc """
  Attempts to process a request to create a new activity.

  Returns:

  .`{:ok, %ActivityRevision{}}` when the creation processes succeeds
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to create this activity
  .`{:error, {:error}}` unknown error
  """
  @spec create(String.t, String.t, %Author{}, %{})
    :: {:ok, %ActivityRevision{}} | {:error, {:not_found}} | {:error, {:error}} | {:error, {:not_authorized}}
  def create(project_slug, activity_type_slug, author, model) do

    Repo.transaction(fn ->

      with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <- Publishing.get_unpublished_publication(project_slug, author.id) |> trap_nil(),
         {:ok, family} <- Activities.create_activity_family(),
         {:ok, activity} <- Activities.create_activity(%{project_id: project.id, family_id: family.id}),
         {:ok, activity_type} <- Activities.get_registration_by_slug(activity_type_slug) |> trap_nil(),
         {:ok, revision} <- Activities.create_activity_revision(%{objectives: [%{}], author_id: author.id, activity_id: activity.id, content: model, activity_type_id: activity_type.id}),
         {:ok, _mapping} <- Publishing.create_activity_mapping(%{publication_id: publication.id, activity_id: activity.id, revision_id: revision.id})
      do
        revision
      else
        error -> Repo.rollback(error)
      end

    end)

  end

end
