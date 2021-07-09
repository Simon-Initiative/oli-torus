defmodule Oli.Publishing.ChangeTracker do
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver

  @doc """
  Tracks the creation of a new revision for the current
  unpublished publication.  If `changes` argument is
  supplied it treats the `revision` argument as a base
  revision and creates a new revision from this base with
  the applied changes.  If `changes` argument is not supplied or
  is nil, then the `revision` argument is assumed to be an
  already new revision.
  """
  def track_revision(project_slug, revision, changes \\ nil) do
    process_change(
      project_slug,
      revision,
      &Oli.Resources.create_revision_from_previous/2,
      changes
    )
  end

  defp process_change(project_slug, revision, processor, changes) do
    publication = Publishing.working_project_publication(project_slug)

    {:ok, resultant_revision} =
      case changes do
        nil -> {:ok, revision}
        c -> processor.(revision, c)
      end

    Publishing.upsert_published_resource(publication, resultant_revision)
  end
end
