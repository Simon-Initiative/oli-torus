defmodule Oli.Authoring.Audited.Imports do
  @moduledoc false

  # Import commands of `Oli.Authoring.Audited`, which validates their arguments. The Google Doc
  # import creates its page through `ContainerEditor.add_new/4` (creation, which stays public)
  # and records `google_doc_imported` in the same transaction; the import's media and
  # activities are committed before, as they were. The metadata CSV row is the in-place
  # revision update moved from `OliWeb.Import.CSVImportView`.

  import Oli.Authoring.Audited.Support,
    only: [lock_working_mappings: 2, record: 2, record_replacement: 5]

  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo
  alias Oli.Resources

  @metadata_fields [:duration_minutes, :poster_image, :intro_video, :intro_content]

  ## Commands

  def import_google_doc_page(context, project, container, author, attrs, details) do
    Repo.transaction(fn ->
      with {:ok, revision} <- ContainerEditor.add_new(container, attrs, author, project),
           :ok <- record_google_doc_import(context, project, revision, details.(revision)) do
        revision
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def import_metadata_row(context, project, revision_slug, change) do
    change = Map.take(change, @metadata_fields)

    Repo.transaction(fn ->
      with %{resource_id: resource_id} <-
             AuthoringResolver.from_revision_slug(project.slug, revision_slug),
           :ok <- lock_working_mappings(project, [resource_id]),
           revision when not is_nil(revision) <-
             AuthoringResolver.from_resource_id(project.slug, resource_id) do
        case Map.take(revision, @metadata_fields) == change do
          true -> :unchanged
          false -> update_metadata(context, project, revision, change)
        end
      else
        nil -> Repo.rollback(:not_found)
      end
    end)
  end

  # Updates the revision in place, as the CSV import did
  defp update_metadata(context, project, revision, change) do
    with {:ok, updated} <- Resources.update_revision(revision, change),
         :ok <- record_replacement(context, project, revision, updated, "metadata_csv") do
      updated
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp record_google_doc_import(context, project, revision, details) do
    record(context, %{
      event_type: :google_doc_imported,
      entity: {:project, project.id, project},
      scope: %{project_id: project.id, resource_id: revision.resource_id},
      details: details,
      event_key: "project:#{project.id}:google_doc_imported"
    })
  end
end
