defmodule Oli.Interop.Ingest.Processor.BibEntries do
  alias Oli.Interop.Ingest.State
  import Oli.Interop.Ingest.Processor.Common

  def process(%State{} = state) do
    State.notify_step_start(state, :bib_entries)
    |> create_revisions(
      :bib_entries,
      Oli.Resources.ResourceType.get_id_by_type("bibentry"),
      &mapper/3
    )
  end

  def mapper(%State{slug_prefix: slug_prefix}, resource_id, resource) do
    legacy_id = Map.get(resource, "legacyId", nil)
    legacy_path = Map.get(resource, "legacyPath", nil)
    title = Map.get(resource, "title", "missing title")
    content = Map.get(resource, "content", %{})

    %{
      slug: Oli.Utils.Slug.slug_with_prefix(slug_prefix, title),
      legacy: %Oli.Resources.Legacy{id: legacy_id, path: legacy_path},
      resource_id: resource_id,
      tags: {:placeholder, :tags},
      title: title,
      content: content,
      author_id: {:placeholder, :author_id},
      objectives: {:placeholder, :objectives},
      resource_type_id: {:placeholder, :resource_type_id},
      inserted_at: {:placeholder, :now},
      updated_at: {:placeholder, :now}
    }
  end
end
