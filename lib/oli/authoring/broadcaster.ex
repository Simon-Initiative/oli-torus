defmodule Oli.Authoring.Broadcaster do

  @moduledoc """

  This module encapsulates all broadcasting functionality for authoring events.

  For some broadcast functions in this module, more than one actual PubSub broadcast is performed
  to allow clients to opt-in to receiving updates for a specific context, whether
  that is a specific project or a specific resource type.

  """

  alias Phoenix.PubSub

  @doc """
  Broadcasts that a revision for an existing resource has changed or been created.
  """
  def broadcast_revision(revision, project_slug) do
    PubSub.broadcast Oli.PubSub, "resource:" <> Integer.to_string(revision.resource_id),
      {:updated, revision, project_slug}
    PubSub.broadcast Oli.PubSub, "resource:" <> Integer.to_string(revision.resource_id) <> ":project:" <> project_slug,
      {:updated, revision, project_slug}
  end

  @doc """
  Broadcasts that a new resource has been created.
  """
  def broadcast_resource(revision, project_slug) do
    PubSub.broadcast Oli.PubSub, "new_resource:project:" <> project_slug,
      {:new_resource, revision, project_slug}
    PubSub.broadcast Oli.PubSub, "new_resource:resource_type:" <> Integer.to_string(revision.resource_type_id) <> ":project:" <> project_slug,
      {:new_resource, revision, project_slug}
  end

  @doc """
  Broadcasts that the unpublished publication has been published
  """
  def broadcase_publication(publication, project_slug) do
    PubSub.broadcast Oli.PubSub, "new_publication:project:" <> project_slug,
      {:new_publication, publication, project_slug}

  end





end
