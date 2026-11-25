defmodule Oli.Authoring.Audited.Alternatives do
  @moduledoc false
  # Alternatives group commands of `Oli.Authoring.Audited`, which validates their arguments.
  # Groups are a project setting, so their changes record `project_settings_changed`.

  import Oli.Authoring.Audited.Support,
    only: [lock_working_mappings: 2, record: 2, resource_ids: 1]

  alias Oli.Authoring.Course
  alias Oli.Authoring.Editing.{AlternativesOptionEditor, ResourceEditor}
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo

  @alternatives_type_id Oli.Resources.ResourceType.id_for_alternatives()

  # Locks the group's working mapping and reads it, so the recorded before-state is the one the
  # write replaces
  defp locked_group(project_slug, resource_id) do
    with %{} = project <- Course.get_project_by_slug(project_slug),
         [id] <- resource_ids([resource_id]) do
      lock_working_mappings(project, [id])
      AuthoringResolver.from_resource_id(project_slug, id)
    else
      _ -> nil
    end
  end

  def create_alternatives_group(context, project_slug, author, attrs) do
    Repo.transaction(fn ->
      with {:ok, group} <-
             ResourceEditor.create(project_slug, author, @alternatives_type_id, attrs),
           :ok <- record_group(context, project_slug, group, nil, group) do
        group
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def edit_alternatives_group(context, project_slug, resource_id, author, update) do
    Repo.transaction(fn ->
      before = locked_group(project_slug, resource_id)

      with {:ok, group} <- ResourceEditor.edit(project_slug, resource_id, author, update),
           :ok <- record_group(context, project_slug, group, before, group) do
        group
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def move_alternatives_option(
        context,
        project_slug,
        author,
        groups,
        resource_id,
        option_id,
        drop_index
      ) do
    Repo.transaction(fn ->
      before = locked_group(project_slug, resource_id)

      case AlternativesOptionEditor.move_to(
             project_slug,
             author,
             groups,
             resource_id,
             option_id,
             drop_index
           ) do
        {:ok, :unchanged} ->
          :unchanged

        {:ok, updated_groups, group} ->
          case record_group(context, project_slug, group, before, group) do
            :ok -> {updated_groups, group}
            {:error, reason} -> Repo.rollback(reason)
          end

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, :unchanged} -> {:ok, :unchanged}
      {:ok, {updated_groups, group}} -> {:ok, updated_groups, group}
      error -> error
    end
  end

  defp record_group(context, project_slug, group, before, after_group) do
    old = before && group_summary(before)
    new = group_summary(after_group)

    changes =
      case old do
        nil ->
          %{"alternatives_groups" => %{"operation" => "added", "after" => [new]}}

        ^new ->
          %{}

        old ->
          %{"alternatives_groups" => %{"operation" => "set", "before" => [old], "after" => [new]}}
      end

    case map_size(changes) do
      0 ->
        :ok

      _ ->
        project = Course.get_project_by_slug(project_slug)

        record(context, %{
          event_type: :project_settings_changed,
          entity: {:project, project.id, project},
          scope: %{project_id: project.id},
          event_key: "project:#{project.id}:settings_changed",
          changes: changes,
          details: %{alternatives_group_id: group.resource_id}
        })
    end
  end

  defp group_summary(group) do
    content = group.content || %{}

    %{
      "resource_id" => group.resource_id,
      "title" => group.title,
      "strategy" => content["strategy"],
      "options" => Enum.map(content["options"] || [], &%{"id" => &1["id"], "name" => &1["name"]})
    }
  end
end
