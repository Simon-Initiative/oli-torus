defmodule Oli.Authoring.Broadcaster do
  @moduledoc """

  This module encapsulates all broadcasting functionality for authoring events.

  For some broadcast functions in this module, more than one actual PubSub broadcast is performed
  to allow clients to opt-in to receiving updates for a specific context, whether
  that is a specific project or a specific resource type.

  """

  import Oli.Authoring.Broadcaster.Messages
  alias Phoenix.PubSub

  ### Broadcast events

  @doc """
  Broadcasts that a revision for an existing resource has changed or been created.
  """
  def broadcast_revision(revision, project_slug) do
    PubSub.broadcast(
      Oli.PubSub,
      message_new_revision(revision.resource_id),
      {:updated, revision, project_slug}
    )

    PubSub.broadcast(
      Oli.PubSub,
      message_new_revisions_in_project(revision.resource_id, project_slug),
      {:updated, revision, project_slug}
    )
  end

  @doc """
  Broadcasts that a new resource has been created.
  """
  def broadcast_resource(revision, project_slug) do
    PubSub.broadcast(
      Oli.PubSub,
      message_new_resource(project_slug),
      {:new_resource, revision, project_slug}
    )

    PubSub.broadcast(
      Oli.PubSub,
      message_new_resource_of_type(revision.resource_type_id, project_slug),
      {:new_resource, revision, project_slug}
    )
  end

  @doc """
  Broadcasts that the unpublished publication has been published
  """
  def broadcast_publication(publication, project_slug) do
    PubSub.broadcast(
      Oli.PubSub,
      message_new_publication(project_slug),
      {:new_publication, publication, project_slug}
    )
  end

  @doc """
  Broadcasts that a new review has been executed for a project
  """
  def broadcast_review(project_slug) do
    PubSub.broadcast(
      Oli.PubSub,
      message_new_review(project_slug),
      {:new_review, project_slug}
    )
  end

  @doc """
  Broadcasts that a warning has been dismissed for a project
  """
  def broadcast_dismiss_warning(warning_id, project_slug) do
    PubSub.broadcast(
      Oli.PubSub,
      message_dismiss_warning(project_slug),
      {:dismiss_warning, warning_id, project_slug}
    )
  end

  @doc """
  Broadcasts that a lock has been acquired on a resource
  """
  def broadcast_lock_acquired(resource_id, author_id) do
    PubSub.broadcast(
      Oli.PubSub,
      message_lock_acquired(resource_id),
      {:lock_acquired, resource_id, author_id}
    )
  end

  @doc """
  Broadcasts that a lock has been released on a resource
  """
  def broadcast_lock_released(resource_id) do
    PubSub.broadcast(
      Oli.PubSub,
      message_lock_released(resource_id),
      {:lock_released, resource_id}
    )
  end

end
