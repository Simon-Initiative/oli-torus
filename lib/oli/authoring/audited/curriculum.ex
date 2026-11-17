defmodule Oli.Authoring.Audited.Curriculum do
  @moduledoc false

  # Page options and curriculum structure commands of `Oli.Authoring.Audited`, which validates
  # their arguments, and the writes they run. Moved from `ContainerEditor`: `edit_page/3`,
  # `move_to/5`, and `reorder_child/5`, with `remove_from_container/4`.
  # `append_to_container/4` and `maybe_restore_deleted_revision/3` are copies of the
  # `ContainerEditor` helpers, which `ContainerEditor.add_new/4` (creation, not audited) keeps.

  import Oli.Authoring.Editing.Utils

  import Oli.Authoring.Audited.Support,
    only: [changing: 4, page_settings: 0, record_resource_change: 5]

  alias Oli.Accounts.Author
  alias Oli.Auditing.Changes
  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Publishing.{AuthoringResolver, ChangeTracker}
  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Resources.Revision

  ## Commands

  def update_page_options(context, project, revision_slug, change) do
    project
    |> changing(
      slug_ids([revision_slug]),
      fn -> edit_page(project, revision_slug, change) end,
      &record_options(context, project, &1, &2)
    )
    |> tap(fn
      {:ok, revision} -> Broadcaster.broadcast_revision(revision, project.slug)
      _error -> :ok
    end)
  end

  def move_curriculum_entry(context, revision, old_container, new_container, author, project) do
    containers = Enum.reject([old_container, new_container], &is_nil/1)

    project
    |> changing(
      Enum.map(containers, & &1.resource_id),
      fn -> move_to(revision, old_container, new_container, author, project) end,
      &record_children(context, project, &1, &2)
    )
    |> tap(fn
      {:ok, _} ->
        Enum.each(containers, &ContainerEditor.broadcast_update(&1.resource_id, project.slug))

      _error ->
        :ok
    end)
  end

  def reorder_curriculum_entry(context, container, project, author, source_slug, index) do
    project
    |> changing(
      [container.resource_id],
      fn -> reorder_child(container, project, author, source_slug, index) end,
      &record_children(context, project, &1, &2)
    )
    |> case do
      {:ok, {updated_container, rev}} ->
        Broadcaster.broadcast_revision(updated_container, project.slug)
        {:ok, rev}

      error ->
        error
    end
  end

  # Page options record their settings and the DOT switch (`ai_enabled`) separately.
  defp record_options(context, project, %Revision{} = before, %Revision{} = revision) do
    with :ok <-
           record_resource_change(
             context,
             project,
             revision,
             :authoring_settings_changed,
             Changes.diff(before, revision, page_settings())
           ) do
      record_resource_change(
        context,
        project,
        revision,
        :dot_settings_changed,
        Changes.diff(before, revision, %{ai_enabled: :value})
      )
    end
  end

  defp record_options(_context, _project, _before, _after), do: :ok

  # A move records each container's children before and after; a move between containers
  # records one event per container.
  defp record_children(context, project, %Revision{} = before, %Revision{} = container) do
    record_resource_change(
      context,
      project,
      container,
      :curriculum_changed,
      Changes.diff(before, container, %{children: :value})
    )
  end

  defp record_children(_context, _project, _before, _after), do: :ok

  defp slug_ids(slugs) do
    Enum.flat_map(slugs, fn slug ->
      case Resources.get_resource_from_slug(slug) do
        nil -> []
        resource -> [resource.id]
      end
    end)
  end

  ## Writes

  def edit_page(%Project{} = project, revision_slug, change) do
    # safe guard that we do never allow content or objective changes
    atomized_change =
      for {key, val} <- change,
          into: %{},
          do:
            {if is_binary(key) do
               String.to_atom(key)
             else
               key
             end, val}

    change =
      atomized_change
      |> Map.delete(:content)
      |> Map.delete(:objectives)

    # ensure that changing a page to practice resets the max attempts to 0
    change =
      case Map.get(change, :graded, "true") do
        "false" -> Map.put(change, :max_attempts, 0)
        _ -> change
      end

    Repo.transaction(fn ->
      revision = AuthoringResolver.from_revision_slug(project.slug, revision_slug)

      case ChangeTracker.track_revision(project.slug, revision, change) do
        {:ok, _} -> AuthoringResolver.from_revision_slug(project.slug, revision_slug)
        {:error, changelist} -> Repo.rollback(changelist)
      end
    end)
  end

  @doc """
  Moves a page or container into another container.

  old_container and/or new_container can either be a %Revision{} or nil for
  the case when a page is move to/from the curriculum.
  """
  def move_to(
        %Revision{} = revision,
        old_container,
        new_container,
        %Author{} = author,
        %Project{} = project
      ) do
    # ensure that the removal and attachment either all succeeds or all fails
    result =
      Repo.transaction(fn ->
        with {:ok, _} <- remove_from_container(old_container, project.slug, revision, author),
             {:ok, _} <- append_to_container(new_container, project.slug, revision, author) do
          revision
        else
          {:error, e} -> Repo.rollback(e)
        end
      end)

    result
  end

  def reorder_child(container, project, author, source, index) do
    # Change here to enable "cross project drag and drop -> if resource is not found (nil),
    # create new resource in this project by cloning the existing resource

    # Get the resource id associated with the source revision

    result =
      Repo.transaction(fn ->
        with {:ok, %{id: resource_id}} <- Resources.get_resource_from_slug(source) |> trap_nil() do
          source_index = Enum.find_index(container.children, fn id -> id == resource_id end)

          # Adjust the insert index based on whether
          # first removing the source would throw off the
          # insertion by 1
          insert_index =
            case source_index do
              nil ->
                index

              s ->
                if s < index do
                  index - 1
                else
                  index
                end
            end

          # Apply the reordering in a way that is as robust as possible to situations
          # where the user that originated the reorder was looking at an out of date
          # version of the page

          # Use filter here to remove the source from anywhere that it was actually found
          children =
            Enum.filter(container.children, fn id -> id !== resource_id end)
            # And insert_at to insert it, in a way that is robust to index positions that
            # don't even make sense
            |> List.insert_at(insert_index, resource_id)

          # Create a change that reorders the children
          reordering = %{
            children: children,
            author_id: author.id
          }

          # Apply that change to the container, generating a new revision
          case ChangeTracker.track_revision(project.slug, container, reordering) do
            {:ok, rev} ->
              updated_container = Oli.Repo.get(Oli.Resources.Revision, rev.id)

              {updated_container, rev}

            e ->
              Repo.rollback(e)
          end
        else
          _ -> Repo.rollback(:not_found)
        end
      end)

    result
  end

  # if no container is specified then this is a no-op
  defp remove_from_container(nil, _project_slug, _revision, _author), do: {:ok, nil}

  defp remove_from_container(container, project_slug, revision, author) do
    # Create a change that removes the child
    removal = %{
      children: Enum.filter(container.children, fn id -> id !== revision.resource_id end),
      author_id: author.id
    }

    ChangeTracker.track_revision(project_slug, container, removal)
  end

  # if no container is specified then this is a no-op
  defp append_to_container(nil, _project_slug, _revision_to_attach, _author), do: {:ok, nil}

  defp append_to_container(container, project_slug, revision_to_attach, author) do
    append = %{
      children: container.children ++ [revision_to_attach.resource_id],
      author_id: author.id
    }

    with {:ok, _} <- ChangeTracker.track_revision(project_slug, container, append),
         {:ok, restored_revision} <-
           maybe_restore_deleted_revision(project_slug, revision_to_attach, author) do
      {:ok, restored_revision}
    end
  end

  defp maybe_restore_deleted_revision(project_slug, revision_to_attach, author) do
    case revision_to_attach.deleted do
      true ->
        ChangeTracker.track_revision(project_slug, revision_to_attach, %{
          deleted: false,
          author_id: author.id
        })

      _ ->
        {:ok, revision_to_attach}
    end
  end
end
