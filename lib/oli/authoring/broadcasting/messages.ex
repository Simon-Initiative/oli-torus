defmodule Oli.Authoring.Broadcaster.Messages do
  ### Message creation API

  def message_new_revision(resource_id) do
    resource(resource_id)
  end

  def message_new_revisions_in_project(resource_id, project_slug) do
    [resource(resource_id), project(project_slug)] |> join
  end

  def message_new_resource(project_slug) do
    ["new_resource", project(project_slug)] |> join
  end

  def message_new_resource_of_type(resource_type_id, project_slug) do
    ["new_resource", resource_type(resource_type_id), project(project_slug)] |> join
  end

  def message_new_publication(project_slug) do
    ["new_publication", project(project_slug)] |> join
  end

  def message_new_review(project_slug) do
    ["new_review", project(project_slug)] |> join
  end

  def message_dismiss_warning(project_slug) do
    ["dismiss_warning", project(project_slug)] |> join
  end

  def message_lock_acquired(project_slug, resource_id) do
    ["lock_acquired", project(project_slug), resource(resource_id)] |> join
  end

  def message_lock_released(project_slug, resource_id) do
    ["lock_released", project(project_slug), resource(resource_id)] |> join
  end

  ## Private helpers
  defp resource_type(resource_type_id),
    do: "resource_type:" <> Integer.to_string(resource_type_id)

  defp resource(resource_id), do: "resource:" <> Integer.to_string(resource_id)
  defp project(project_slug), do: "project:" <> project_slug
  defp join(messages), do: Enum.join(messages, ":")
end
