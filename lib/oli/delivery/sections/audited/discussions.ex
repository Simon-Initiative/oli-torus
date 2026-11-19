defmodule Oli.Delivery.Sections.Audited.Discussions do
  @moduledoc false
  # Discussion and notes configuration of sections and products: the course discussion board
  # (the root container's `collab_space_config` and `contains_discussions`), a page's
  # discussion configuration, and the notes toggle for every page.
  #
  # Moved here:
  #   * `Oli.Resources.Collaboration.enable_all_page_collab_spaces_for_section/2` and
  #     `disable_all_page_collab_spaces_for_section/1`.
  #
  # The course board and each page record `discussion_settings_changed`; the notes toggle
  # records one `notes_settings_changed` for the section with the number of pages written.

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Oli.Auditing.{Changes, Command, Context}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Delivery.Sections.{Section, SectionCache, SectionResource}
  alias Oli.Delivery.Sections.Audited.Support
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.ResourceType

  @config_policy Map.delete(Fields.support_configuration(), :contains_discussions)

  # Course discussion board

  def update_course(%Context{} = context, %Section{} = section, config_changes) do
    Command.run(:result, fn multi ->
      multi
      |> Multi.run(:before, fn _repo, _changes -> Support.lock_section(section.id) end)
      |> Multi.run(:root, fn _repo, %{before: before} -> lock_root(before) end)
      |> Multi.run(:section_resource, fn repo, %{root: root} ->
        write_config(repo, root, Map.merge(config_map(root.collab_space_config), config_changes))
      end)
      |> Multi.run(:section, fn repo, %{before: before, section_resource: updated_root} ->
        put_contains_discussions(
          repo,
          before,
          Map.has_key?(config_changes, :status),
          updated_root
        )
      end)
      |> Multi.run(:event, fn _repo, changes ->
        %{before: before, section: updated, root: root, section_resource: updated_root} = changes

        record_course(context, before, updated, root, updated_root)
      end)
      |> Multi.run(:result, fn _repo, %{section: updated, section_resource: updated_root} ->
        {:ok, %{section: updated, section_resource: updated_root}}
      end)
    end)
    |> clear_cache(section)
  end

  defp lock_root(%Section{root_section_resource_id: nil}), do: {:error, :not_found}

  defp lock_root(%Section{} = section) do
    case Oli.Repo.get(SectionResource, section.root_section_resource_id) do
      nil -> {:error, :not_found}
      root -> Support.lock_section_resource(section.id, root.resource_id)
    end
  end

  defp record_course(context, before, updated, root, updated_root) do
    changes =
      Map.merge(
        Changes.diff(root.collab_space_config, updated_root.collab_space_config, @config_policy),
        Changes.diff(before, updated, %{contains_discussions: :value})
      )

    kind = Support.kind(updated)

    case Support.record_many(context, [
           %{
             event_type: :discussion_settings_changed,
             entity: {kind, updated.id, updated},
             scope: Support.scope(updated),
             event_key: "#{kind}:#{updated.id}:discussion_settings_changed",
             changes: changes
           }
         ]) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  # One page

  def update_page(%Context{} = context, %Section{} = section, resource_id, config_attrs) do
    Command.run(:result, fn multi ->
      multi
      |> Multi.run(:before, fn _repo, _changes -> Support.lock_section(section.id) end)
      |> Multi.run(:page, fn _repo, _changes ->
        Support.lock_section_resource(section.id, resource_id)
      end)
      |> Multi.run(:section_resource, fn repo, %{page: page} ->
        write_config(repo, page, config_attrs)
      end)
      |> Multi.run(:section, fn repo, %{before: before, section_resource: updated_page} ->
        put_contains_discussions(repo, before, true, updated_page)
      end)
      |> Multi.run(:event, fn _repo, changes ->
        %{before: before, section: updated, page: page, section_resource: updated_page} = changes

        record_page(context, before, updated, page, updated_page)
      end)
      |> Multi.run(:result, fn _repo, %{section: updated, section_resource: updated_page} ->
        {:ok, %{section: updated, section_resource: updated_page}}
      end)
    end)
    |> clear_cache(section)
  end

  defp record_page(context, before, updated, page, updated_page) do
    changes =
      Map.merge(
        Changes.diff(page.collab_space_config, updated_page.collab_space_config, @config_policy),
        Changes.diff(before, updated, %{contains_discussions: :value})
      )

    case Support.record_many(context, [
           %{
             event_type: :discussion_settings_changed,
             entity: {:resource, page.resource_id, %{title: page.title, slug: page.slug}},
             scope: Map.put(Support.scope(updated), :resource_id, page.resource_id),
             event_key: "resource:#{page.resource_id}:discussion_settings_changed",
             changes: changes
           }
         ]) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  # Notes on every page

  def set_notes(%Context{} = context, %Section{} = section, config) do
    Command.run(:pages, fn multi ->
      multi
      |> Multi.run(:before, fn _repo, _changes -> Support.lock_section(section.id) end)
      |> Multi.run(:enabled_before, fn _repo, %{before: before} ->
        {enabled, _total} =
          Collaboration.count_collab_spaces_enabled_in_pages_for_section(before.slug)

        {:ok, enabled}
      end)
      |> Multi.run(:pages, fn repo, %{before: before} ->
        {count, _rows} =
          repo.update_all(pages_query(before.slug), set: [collab_space_config: stored(config)])

        {:ok, count}
      end)
      |> Multi.run(:event, fn _repo, %{before: before, enabled_before: enabled, pages: count} ->
        record_notes(context, before, enabled, config, count)
      end)
    end)
  end

  defp pages_query(section_slug) do
    page_id = ResourceType.id_for_page()

    from([sr: sr, rev: rev] in DeliveryResolver.section_resource_revisions(section_slug),
      where: rev.resource_type_id == ^page_id and rev.deleted == false,
      select: sr
    )
  end

  defp stored(:disabled), do: %CollabSpaceConfig{}
  defp stored(%CollabSpaceConfig{} = config), do: config

  defp record_notes(context, section, enabled_before, config, count) do
    before_status =
      case enabled_before do
        0 -> :disabled
        _ -> :enabled
      end

    after_state =
      case config do
        :disabled -> %{status: :disabled}
        %CollabSpaceConfig{} -> config
      end

    kind = Support.kind(section)

    case Support.record_many(context, [
           %{
             event_type: :notes_settings_changed,
             entity: {kind, section.id, section},
             scope: Support.scope(section),
             event_key: "#{kind}:#{section.id}:notes_settings_changed",
             changes: Changes.diff(%{status: before_status}, after_state, @config_policy),
             details: %{page_count: count}
           }
         ]) do
      :ok -> {:ok, nil}
      error -> error
    end
  end

  # Writes

  defp write_config(repo, section_resource, config_attrs) do
    section_resource
    |> SectionResource.changeset(%{collab_space_config: config_attrs})
    |> repo.update()
  end

  # The section's discussion flag follows the status written: enabled sets it, disabled clears
  # it, and archived leaves it as it was.
  defp put_contains_discussions(_repo, section, false, _section_resource), do: {:ok, section}

  defp put_contains_discussions(repo, section, true, %SectionResource{} = section_resource) do
    case section_resource.collab_space_config do
      %CollabSpaceConfig{status: :enabled} -> set_contains_discussions(repo, section, true)
      %CollabSpaceConfig{status: :disabled} -> set_contains_discussions(repo, section, false)
      _config -> {:ok, section}
    end
  end

  defp set_contains_discussions(repo, section, value) do
    section |> Section.changeset(%{contains_discussions: value}) |> repo.update()
  end

  defp config_map(nil), do: %{}
  defp config_map(%CollabSpaceConfig{} = config), do: Map.from_struct(config)

  defp clear_cache({:ok, %{section: updated} = result}, given) do
    SectionCache.clear(updated.slug, [:ordered_container_labels])
    {:ok, %{result | section: Support.preload_like(updated, given)}}
  end

  defp clear_cache(error, _given), do: error
end
