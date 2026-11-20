defmodule Oli.Delivery.Sections.Audited.PublicationUpdates do
  @moduledoc false
  # Publication updates applied to sections: moved here from
  # `Oli.Delivery.Sections.Updates.apply_publication_update/2`, which read the current
  # publication before taking the section lock and had no actor.
  #
  # The current publication is now read under the lock, so two runs of the same update cannot
  # both see the old publication. An update that changes the section's publication records
  # `publication_applied` (`section_*` or `product_*` entity) with the previous and resulting
  # publications; re-applying the publication already in place runs as before and records
  # nothing.

  alias Oli.Auditing.{Changes, Context}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.DepotCoordinator
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionCache, SectionResourceDepot}
  alias Oli.Delivery.Sections.{SectionResourceMigration, Updates}
  alias Oli.Delivery.Sections.Audited.Support
  alias Oli.Delivery.Updates.{Broadcaster, Worker}
  alias Oli.Publishing
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo

  def apply(%Context{} = context, %Section{} = section, publication_id) do
    case Repo.in_transaction?() do
      true -> {:error, :nested_transaction}
      false -> run(context, section, publication_id)
    end
  end

  def enqueue(%Context{} = context, %Section{slug: slug}, publication_id) do
    slug
    |> Worker.args(publication_id, context)
    |> Worker.new()
    |> Oban.insert()
  end

  defp run(context, section, publication_id) do
    Broadcaster.broadcast_update_progress(section.id, publication_id, 0)

    new_publication = Publishing.get_publication!(publication_id)
    project = Repo.get(Project, new_publication.project_id)

    result =
      Repo.transaction(fn ->
        SectionResourceMigration.lock_section!(section.id)
        current_publication = Sections.get_current_publication(section.id, project.id)

        with {:ok, updated_section} <-
               Updates.apply_in_transaction(
                 section,
                 project.id,
                 current_publication,
                 new_publication
               ),
             :ok <- record(context, section, project, current_publication, new_publication) do
          updated_section
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    case result do
      {:ok, _} ->
        SectionCache.clear(section.slug)
        DepotCoordinator.clear_synchronously(SectionResourceDepot.depot_desc(), section.id)
        Broadcaster.broadcast_update_progress(section.id, new_publication.id, :complete)

      _error ->
        Broadcaster.broadcast_update_progress(section.id, new_publication.id, 0)
    end

    result
  end

  defp record(_context, _section, _project, %Publication{id: id}, %Publication{id: id}),
    do: :ok

  defp record(context, section, project, previous, resulting) do
    kind = Support.kind(section)

    Support.record(context, %{
      event_type: :publication_applied,
      entity: {kind, section.id, section},
      scope:
        Map.reject(
          %{
            section_id: section.id,
            project_id: project.id,
            institution_id: section.institution_id
          },
          fn {_column, value} -> not is_integer(value) end
        ),
      event_key: "#{kind}:#{section.id}:publication:#{resulting.id}:applied",
      refs: refs(previous, resulting),
      changes:
        Changes.diff(
          previous && %{publication_id: previous.id},
          %{publication_id: resulting.id},
          Fields.publication()
        )
    })
  end

  defp refs(previous, resulting) do
    [ref(:previous, previous), ref(:resulting, resulting)]
    |> Enum.reject(&is_nil/1)
  end

  defp ref(_role, nil), do: nil

  defp ref(role, %Publication{} = publication) do
    %{
      role: role,
      type: :publication,
      id: publication.id,
      label: "#{publication.edition}.#{publication.major}.#{publication.minor}"
    }
  end
end
