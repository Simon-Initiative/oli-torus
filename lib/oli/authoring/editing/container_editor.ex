defmodule Oli.Authoring.Editing.ContainerEditor do
  @moduledoc """
  This module provides high-level editing facilities for project
  containers, mainly around adding and removing and reording
  the items within a container.

  """

  import Oli.Authoring.Editing.Utils

  alias Oli.Resources.Revision
  alias Oli.Resources
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing.ChangeTracker
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Repo
  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Activities
  alias Oli.Resources.ScoringStrategy

  @spec edit_page(Oli.Authoring.Course.Project.t(), any, map) :: any
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

    result =
      Repo.transaction(fn ->
        revision = AuthoringResolver.from_revision_slug(project.slug, revision_slug)

        case ChangeTracker.track_revision(project.slug, revision, change) do
          {:ok, _} -> AuthoringResolver.from_revision_slug(project.slug, revision_slug)
          {:error, changelist} -> Repo.rollback(changelist)
        end
      end)

    case result do
      {:ok, revision} ->
        Broadcaster.broadcast_revision(revision, project.slug)
        {:ok, revision}

      e ->
        e
    end
  end

  @doc """
  Lists all top level resource revisions contained in a container.
  """
  def list_all_container_children(container, %Project{} = project) do
    AuthoringResolver.from_resource_id(project.slug, container.children)
    |> Repo.preload([:resource, :author])
  end

  @doc """
  Creates and adds a new page or container as a child of a container.
  """
  def add_new(
        container,
        %{objectives: _, children: _, content: _, title: _} = attrs,
        %Author{} = author,
        %Project{} = project
      ) do
    attrs =
      Map.merge(attrs, %{
        author_id: author.id
      })

    # We want to ensure that the creation and attachment either
    # all succeeds or all fails
    result =
      Repo.transaction(fn ->
        with {:ok, %{revision: revision}} <-
               Oli.Authoring.Course.create_and_attach_resource(project, attrs),
             {:ok, _} <- ChangeTracker.track_revision(project.slug, revision),
             {:ok, _} <- append_to_container(container, project.slug, revision, author) do
          revision
        else
          {:error, e} -> Repo.rollback(e)
        end
      end)

    {status, _} = result

    if status == :ok && container != nil do
      broadcast_update(container.resource_id, project.slug)
    end

    result
  end

  def add_new(
        container,
        type,
        scored,
        %Author{} = author,
        %Project{} = project,
        numberings \\ nil
      )
      when is_binary(type) do
    attrs = %{
      tags: [],
      objectives: %{"attached" => []},
      children: [],
      content:
        case type do
          "Adaptive" ->
            %{
              "model" => [],
              "advancedAuthoring" => true,
              "advancedDelivery" => true,
              "displayApplicationChrome" => false
            }

          _ ->
            %{
              "version" => "0.1.0",
              "model" => []
            }
        end,
      title:
        case type do
          "Adaptive" ->
            case scored do
              "Scored" -> "New Adaptive Assessment"
              "Unscored" -> "New Adaptive Page"
            end

          "Basic" ->
            case scored do
              "Scored" -> "New Assessment"
              "Unscored" -> "New Page"
            end

          "Container" ->
            new_container_name(numberings, container)
        end,
      graded:
        case type do
          "Container" ->
            false

          _ ->
            case scored do
              "Scored" -> true
              "Unscored" -> false
            end
        end,
      max_attempts:
        case type do
          "Container" ->
            nil

          _ ->
            case scored do
              "Scored" -> 5
              "Unscored" -> 0
            end
        end,
      recommended_attempts:
        case type do
          "Container" ->
            nil

          _ ->
            case scored do
              "Scored" -> 5
              "Unscored" -> 0
            end
        end,
      scoring_strategy_id:
        case type do
          "Adaptive" -> ScoringStrategy.get_id_by_type("best")
          "Basic" -> ScoringStrategy.get_id_by_type("best")
          "Container" -> nil
        end,
      resource_type_id:
        case type do
          "Adaptive" -> Oli.Resources.ResourceType.id_for_page()
          "Basic" -> Oli.Resources.ResourceType.id_for_page()
          "Container" -> Oli.Resources.ResourceType.id_for_container()
        end
    }

    add_new(
      container,
      attrs,
      author,
      project
    )
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

    {status, _} = result

    if status == :ok && old_container != nil do
      broadcast_update(old_container.resource_id, project.slug)
    end

    if status == :ok && new_container != nil do
      broadcast_update(new_container.resource_id, project.slug)
    end

    result
  end

  def broadcast_update(resource_id, project_slug) do
    updated_container = AuthoringResolver.from_resource_id(project_slug, resource_id)
    Broadcaster.broadcast_revision(updated_container, project_slug)
  end

  @doc """
  Removes a child from a container, and marks that child as deleted by default.
  """
  def remove_child(container, project, author, revision_slug) do
    with {:ok, %{id: resource_id}} <-
           Resources.get_resource_from_slug(revision_slug) |> trap_nil() do
      children = Enum.filter(container.children, fn id -> id !== resource_id end)

      # Create a change that removes the child
      removal = %{
        children: children,
        author_id: author.id
      }

      # Create a change to mark the child as deleted
      deletion = %{
        deleted: true,
        author_id: author.id
      }

      # Atomically apply the changes
      result =
        Repo.transaction(fn ->
          # It is important to edit the page via PageEditor, since it will ensure
          # that a lock can be acquired before editing. This will not allow the deletion
          # to occur if another user is editing. It *will* allow deletion to occur if
          # this current user is editing this page (like in another tab). This is due
          # to the re-entrant natures of our locks.

          with {:acquired} <- PageEditor.acquire_lock(project.slug, revision_slug, author.email),
               {:ok, _} <- PageEditor.edit(project.slug, revision_slug, author.email, deletion),
               _ <- PageEditor.release_lock(project.slug, revision_slug, author.email),
               {:ok, revision} = ChangeTracker.track_revision(project.slug, container, removal) do
            revision
          else
            {:lock_not_acquired, value} -> Repo.rollback({:lock_not_acquired, value})
            {:error, e} -> Repo.rollback(e)
          end
        end)

      {status, _} = result

      if status == :ok do
        broadcast_update(container.resource_id, project.slug)
      end

      result
    else
      _ -> {:error, :not_found}
    end
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

    case result do
      {:ok, {updated_container, rev}} ->
        Broadcaster.broadcast_revision(updated_container, project.slug)
        {:ok, rev}

      e ->
        e
    end
  end

  @doc """
    Duplicates a page within its project.
    A true deep-copy of all the content is made. Resources and Revisions are created instead of simply referenced.
  """
  def duplicate_page(
        %Revision{} = container,
        page_id,
        %Author{} = author,
        %Project{} = project
      ) do
    original_page =
      Resources.get_revision!(page_id)
      |> Map.from_struct()

    new_page_attrs =
      original_page
      |> Map.drop([:slug, :inserted_at, :updated_at, :resource_id, :resource])
      |> Map.put(:title, "#{original_page.title} (copy)")
      |> Map.put(:content, nil)
      |> Map.put(:previous_revision_id, nil)
      |> then(fn map ->
        if is_nil(map.legacy) do
          map
        else
          Map.put(map, :legacy, Map.from_struct(original_page.legacy))
        end
      end)

    Repo.transaction(fn ->
      with {:ok, created_revision} <- add_new(container, new_page_attrs, author, project),
           {:ok, model_duplicated_activities} <-
             deep_copy_activities(
               original_page.content,
               project.slug,
               author
             ),
           {:ok, updated_revision} <-
             Resources.update_revision(created_revision, %{content: model_duplicated_activities}) do
        updated_revision
      else
        {:error, e} -> Repo.rollback(e)
      end
    end)
  end

  def deep_copy_activities(model, project_slug, author) do
    {mapped, result} =
      Oli.Resources.PageContent.map_reduce(model, {:ok}, fn e, {status}, _tr_context ->
        case e do
          %{"type" => "activity-reference"} = ref ->
            case deep_copy_activity(ref, project_slug, author) do
              {:ok, updated_activity_reference} ->
                {updated_activity_reference, {status}}

              {:error, _} ->
                {ref, {:error}}
            end

          other ->
            {other, {status}}
        end
      end)

    case result do
      {:ok} ->
        {:ok, mapped}

      {:error} ->
        {:error, :failed_to_duplicate_activities}
    end
  end

  def deep_copy_activity(%{"type" => "activity-reference"} = item, project_slug, author) do
    activity_revision = AuthoringResolver.from_resource_id(project_slug, item["activity_id"])

    activity_type = Activities.get_registration(activity_revision.activity_type_id)

    case ActivityEditor.create(
           project_slug,
           activity_type.slug,
           author,
           activity_revision.content,
           [],
           "embedded",
           activity_revision.title,
           activity_revision.objectives
         ) do
      {:ok, {revision, _}} ->
        {:ok,
         %{
           "id" => item["id"],
           "type" => "activity-reference",
           "children" => [],
           "activity_id" => revision.resource_id
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  def deep_copy_activity(item, _project_slug, _author), do: {:ok, item}

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

    ChangeTracker.track_revision(project_slug, container, append)
  end
end
