defmodule Oli.Interop.Ingest.Processor do
  alias Oli.Interop.Ingest.State
  alias Oli.Repo

  alias Oli.Interop.Ingest.Processor.{
    Tags,
    Pages,
    Objectives,
    Activities,
    Project,
    Hierarchy,
    Products,
    BibEntries,
    Hyperlinks,
    PublishedResources
  }

  def process(%State{} = state) do
    Repo.transaction(fn _ ->
      state
      |> init
      |> Project.process()
      |> bulk_allocate_resources
      |> Tags.process()
      |> Objectives.process()
      |> BibEntries.process()
      |> Activities.process()
      |> Pages.process()
      |> PublishedResources.process()
      |> Hyperlinks.process()
      |> Hierarchy.process()
      |> Products.process()
      |> force_rollback_if_error()
    end)
  end

  defp force_rollback_if_error(%State{force_rollback: nil} = state), do: state
  defp force_rollback_if_error(%State{force_rollback: e}), do: Repo.rollback(e)

  defp bulk_allocate_resources(%State{project: project} = state) do
    total_needed =
      Enum.count(state.tags) + Enum.count(state.bib_entries) + Enum.count(state.objectives) +
        Enum.count(state.activities) + Enum.count(state.pages)

    %{
      state
      | resource_id_pool: Oli.Publishing.create_resource_batch(project, total_needed)
    }
  end

  defp init(%State{} = state) do
    registration_by_subtype =
      Oli.Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn e, m -> Map.put(m, e.slug, e.id) end)

    %{
      state
      | legacy_to_resource_id_map: %{},
        registration_by_subtype: registration_by_subtype,
        container_id_map: %{},
        force_rollback: nil
    }
  end
end
