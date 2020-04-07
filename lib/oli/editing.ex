defmodule Oli.Editing do

  alias Oli.Locks
  alias Oli.Publishing
  alias Oli.Resources
  alias Oli.Repo

  def edit(project_slug, revision_slug, user_id, update) do

    # We need all of this to operate atomically
    Repo.transaction(fn ->

      publication = Publishing.get_unpublished_publication!(project_slug, user_id)
      resource = Resources.get_resource_from_slugs!(project_slug, revision_slug)

      # update the lock
      case Locks.acquire_or_update(publication.id, resource.id, user_id) do

        # If we reacquired the lock, we must first create a new revision
        {:acquired} -> get_latest_revision(publication, resource)
          |> create_new_revision(publication, resource, user_id)
          |> update_revision(update)

        # A successful lock update means we can safely edit the existing revision
        {:updated} -> get_latest_revision(publication, resource)
          |> update_revision(update)

        # error or not able to lock results in a failed edit
        result -> Repo.rollback(result)
      end

    end)

  end

  defp get_latest_revision(publication, resource) do
    mapping = Publishing.get_resource_mapping!(publication.id, resource.id)
    Resources.get_resource_revision!(mapping.revision_id)
  end

  defp create_new_revision(previous, publication, resource, author_id) do
    {:ok, revision} = Resources.create_resource_revision(%{
      children: previous.children,
      content: previous.content,
      objectives: previous.objectives,
      deleted: previous.deleted,
      slug: previous.slug,
      title: previous.title,
      author_id: author_id,
      resource_id: previous.resource_id,
      previous_revision_id: previous.id,
      resource_type_id: previous.resource_type_id
    })

    mapping = Publishing.get_resource_mapping!(publication.id, resource.id)
    {:ok, _mapping} = Publishing.update_resource_mapping(mapping, %{ revision_id: revision.id })

    revision
  end

  defp update_revision(revision, update) do
    {:ok, updated} = Resources.update_resource_revision(revision, update)
    updated
  end

end

