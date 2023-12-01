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
  Broadcasts that a warning has been created for a project. Only broadcasted
  for warnings that can be generated async.
  """
  def broadcast_new_warning(warning_id, project_slug) do
    PubSub.broadcast(
      Oli.PubSub,
      message_new_warning(project_slug),
      {:new_warning, warning_id, project_slug}
    )
  end

  @doc """
  Broadcasts that a lock has been acquired on a resource
  """
  def broadcast_lock_acquired(project_slug, publication_id, resource_id, author_id) do
    PubSub.broadcast(
      Oli.PubSub,
      message_lock_acquired(project_slug, resource_id),
      {:lock_acquired, publication_id, resource_id, author_id}
    )
  end

  @doc """
  Broadcasts that a lock has been released on a resource
  """
  def broadcast_lock_released(project_slug, publication_id, resource_id) do
    PubSub.broadcast(
      Oli.PubSub,
      message_lock_released(project_slug, resource_id),
      {:lock_released, publication_id, resource_id}
    )
  end

  @doc """
  Broadcasts a raw analytics export status update
  """
  def broadcast_analytics_export_status(project_slug, status) do
    PubSub.broadcast(
      Oli.PubSub,
      message_analytics_export_status(project_slug),
      {:analytics_export_status, status}
    )
  end

  @doc """
  Broadcasts a datashop export status update
  """
  def broadcast_datashop_export_status(project_slug, status) do
    PubSub.broadcast(
      Oli.PubSub,
      message_datashop_export_status(project_slug),
      {:datashop_export_status, status}
    )
  end

  @doc """
  Broadcasts a datashop export batch started update
  """
  def broadcast_datashop_export_batch_started(project_slug, current_batch, batch_count) do
    PubSub.broadcast(
      Oli.PubSub,
      message_datashop_export_batch_started(project_slug),
      {:datashop_export_batch_started, {:batch_started, current_batch, batch_count}}
    )
  end

  @doc """
  Broadcasts a datashop export status update
  """
  def broadcast_revision_embedding(publication_id, status) do
    PubSub.broadcast(
      Oli.PubSub,
      message_revision_embedding(publication_id),
      {:revision_embedding_complete, status}
    )
  end
end
