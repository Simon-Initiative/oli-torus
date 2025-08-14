defmodule Oli.Interop.Ingest.Processor do
  @moduledoc """
  The ingest processer takes an already pre-processed ingest state struct and
  executes all the database writes necessary to complete the ingest.
  """

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
    PublishedResources,
    MediaItems,
    Alternatives,
    InternalActivityRefs
  }

  # for prior error such as bad zip file
  def process(%State{entries: nil}), do: {:error, "no entries to process"}

  def process(%State{} = state) do
    Repo.transaction(fn _ ->
      state
      |> init
      |> Project.process()
      |> bulk_allocate_resources
      |> Tags.process()
      |> Alternatives.process()
      |> Objectives.process()
      |> BibEntries.process()
      |> Activities.process()
      |> Pages.process()
      |> PublishedResources.process()
      |> InternalActivityRefs.process()
      |> Hyperlinks.process()
      |> Hierarchy.process()
      |> Products.process()
      |> MediaItems.process()
      |> force_rollback_if_error()
    end)
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
        force_rollback: nil,
        slug_prefix: Oli.Utils.Slug.get_unique_prefix("revisions")
    }
  end

  # For all resource types except containers, we bulk allocate the %Resource and %ProjectResource
  # records in the most efficent manner possible: leveraging a custom database function to do this
  # bulk creation.
  defp bulk_allocate_resources(%State{project: project} = state) do
    total_needed =
      Enum.count(state.tags) + Enum.count(state.bib_entries) + Enum.count(state.objectives) +
        Enum.count(state.activities) + Enum.count(state.pages) + Enum.count(state.alternatives)

    %{
      state
      | resource_id_pool: Oli.Publishing.create_resource_batch(project, total_needed)
    }
  end

  defp force_rollback_if_error(%State{force_rollback: nil} = state), do: state
  defp force_rollback_if_error(%State{force_rollback: e}), do: Repo.rollback(e)
end
