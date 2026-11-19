defmodule Oli.Authoring.Audited.Discussions do
  @moduledoc false
  # Discussion configuration of a project's pages, edited from the page editor and the project
  # overview.
  #
  # Moved here:
  #   * `Oli.Resources.Collaboration.upsert_collaborative_space/4`, which creates the page's next
  #     working revision with the new configuration;
  #   * `Oli.Resources.Collaboration.enable_all_page_collab_spaces_for_project/2` and
  #     `disable_all_page_collab_spaces_for_project/1`, which rewrite the configuration of every
  #     page in the working publication.
  #
  # A page records `discussion_settings_changed` with its previous and resulting revisions; the
  # project-wide toggle records one `discussion_settings_changed` for the project with the
  # number of pages written.

  import Ecto.Query, only: [from: 2, exclude: 2, select: 3, where: 3]

  alias Oli.Auditing.{Changes, Context}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Authoring.Audited.Support
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Resources.{ResourceType, Revision}
  alias Oli.Resources.Collaboration.CollabSpaceConfig

  @config_policy Map.delete(Fields.support_configuration(), :contains_discussions)

  # One page

  def update_page(%Context{} = context, %Project{} = project, page_slug, attrs, author_id) do
    with {:ok, page_resource} <- page_resource(page_slug) do
      Support.changing(
        project,
        [page_resource.id],
        fn -> upsert(attrs, project, page_resource, author_id) end,
        &record_page(context, project, &1, &2)
      )
    end
  end

  defp page_resource(page_slug) do
    case Resources.get_resource_from_slug(page_slug) do
      nil -> {:error, :not_found}
      page_resource -> {:ok, page_resource}
    end
  end

  defp upsert(attrs, project, page_resource, author_id) do
    with %Publication{} = publication <- Publishing.project_working_publication(project.slug),
         %Revision{} = page_revision <-
           Publishing.get_published_revision(publication.id, page_resource.id),
         {:ok, next_page_revision} <-
           Resources.create_revision_from_previous(page_revision, %{
             collab_space_config: attrs,
             author_id: author_id
           }),
         {:ok, _mapping} <- Publishing.upsert_published_resource(publication, next_page_revision) do
      {:ok,
       %{
         project: project,
         publication: publication,
         page_resource: page_resource,
         next_page_revision: next_page_revision
       }}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp record_page(context, project, previous, resulting) do
    case Changes.diff(previous.collab_space_config, resulting.collab_space_config, @config_policy) do
      changes when map_size(changes) == 0 ->
        :ok

      changes ->
        Support.record(context, %{
          event_type: :discussion_settings_changed,
          entity:
            {:resource, resulting.resource_id, %{title: resulting.title, slug: resulting.slug}},
          scope: %{project_id: project.id, resource_id: resulting.resource_id},
          refs: [
            %{role: :previous, type: :revision, id: previous.id, label: previous.title},
            %{role: :resulting, type: :revision, id: resulting.id, label: resulting.title}
          ],
          event_key: "resource:#{resulting.resource_id}:discussion_settings_changed",
          changes: changes
        })
    end
  end

  # Every page

  def set_project(%Context{} = context, %Project{} = project, config) do
    Repo.transaction(fn ->
      page_ids = working_page_ids(project)
      :ok = Support.lock_working_mappings(project, page_ids)
      enabled_before = count_enabled(project)

      {count, _rows} =
        project
        |> working_pages()
        |> Repo.update_all(set: [collab_space_config: stored(config)])

      case record_project(context, project, enabled_before, config, count) do
        :ok -> count
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp working_pages(project) do
    page_id = ResourceType.id_for_page()

    from(rev in Revision,
      join: m in PublishedResource,
      on: m.revision_id == rev.id,
      join: pub in Publication,
      on: pub.id == m.publication_id,
      where:
        pub.project_id == ^project.id and is_nil(pub.published) and
          rev.resource_type_id == ^page_id and rev.deleted == false,
      select: rev
    )
  end

  defp working_page_ids(project) do
    project
    |> working_pages()
    |> exclude(:select)
    |> select([rev], rev.resource_id)
    |> Repo.all()
  end

  defp count_enabled(project) do
    project
    |> working_pages()
    |> exclude(:select)
    |> where([rev], fragment("?->>'status' = 'enabled'", rev.collab_space_config))
    |> select([rev], count(rev.id))
    |> Repo.one()
  end

  defp stored(:disabled), do: %CollabSpaceConfig{}
  defp stored(%CollabSpaceConfig{} = config), do: config

  defp record_project(context, project, enabled_before, config, count) do
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

    case Changes.diff(%{status: before_status}, after_state, @config_policy) do
      changes when map_size(changes) == 0 ->
        :ok

      changes ->
        Support.record(context, %{
          event_type: :discussion_settings_changed,
          entity: {:project, project.id, project},
          scope: %{project_id: project.id},
          event_key: "project:#{project.id}:discussion_settings_changed",
          changes: changes,
          details: %{page_count: count}
        })
    end
  end
end
