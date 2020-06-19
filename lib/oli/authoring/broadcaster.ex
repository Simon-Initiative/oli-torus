defmodule Oli.Authoring.Broadcaster do

  alias Phoenix.PubSub

  @doc """
  Broadcasts resource and project specific message indicating the creation or editing
  of a revision by an authoring component.
  """
  def broadcast_revision(revision, project_slug) do
    PubSub.broadcast Oli.PubSub, "resource:" <> Integer.to_string(revision.resource_id),
      {:updated, revision, project_slug}
    PubSub.broadcast Oli.PubSub, "resource:" <> Integer.to_string(revision.resource_id) <> ":project:" <> project_slug,
      {:updated, revision, project_slug}
  end

end
