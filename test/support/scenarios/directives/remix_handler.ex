defmodule Oli.Scenarios.Directives.RemixHandler do
  @moduledoc """
  Handles remix directives for mixing content between projects and sections.
  """

  alias Oli.Scenarios.DirectiveTypes.RemixDirective
  alias Oli.Scenarios.Engine
  alias Oli.Publishing

  def handle(
        %RemixDirective{
          from: source_name,
          to: target_name,
          resource: resource_title,
          position: position
        },
        state
      ) do
    try do
      # Get source project
      source_project =
        Engine.get_project(state, source_name) ||
          raise "Source project '#{source_name}' not found"

      # Get target (can be project or section)
      {target_type, target} = get_target(state, target_name)

      # Find the resource to remix
      resource_id =
        source_project.id_by_title[resource_title] ||
          raise "Resource '#{resource_title}' not found in source project"

      # Get the latest publication for source
      source_pub = get_or_create_publication(state, source_name, source_project)

      # Perform the remix based on target type
      case target_type do
        :section ->
          remix_into_section(target, resource_id, target_name, position, source_pub, state)

        :project ->
          remix_into_project(target, resource_id, target_name, position, source_project, state)
      end

      {:ok, state}
    rescue
      e ->
        {:error, "Failed to remix: #{Exception.message(e)}"}
    end
  end

  defp get_target(state, name) do
    case Engine.get_section(state, name) do
      nil ->
        case Engine.get_project(state, name) do
          nil -> raise "Target '#{name}' not found (neither project nor section)"
          project -> {:project, project}
        end

      section ->
        {:section, section}
    end
  end

  defp get_or_create_publication(state, _project_name, built_project) do
    # Get the latest published publication or create one
    case Publishing.get_latest_published_publication_by_slug(built_project.project.slug) do
      nil ->
        {:ok, pub} =
          Publishing.publish_project(
            built_project.project,
            "initial",
            state.current_author.id
          )

        pub

      pub ->
        pub
    end
  end

  defp remix_into_section(_section, _resource_id, _to, _position, _source_pub, _state) do
    # Note: Actual remixing into sections is complex and requires 
    # the full remix infrastructure which is not yet fully implemented.
    # For now, this is a placeholder that acknowledges the remix was requested.
    # In production, this would use the proper remix queue and processing.
    :ok
  end

  defp remix_into_project(target_project, resource_id, to, _position, source_project, state) do
    # Get the container to remix into
    to_id =
      target_project.id_by_title[to || "root"] ||
        raise "Container '#{to}' not found in target project"

    # Get source revision
    source_rev =
      source_project.rev_by_title[
        Enum.find_value(source_project.id_by_title, fn {title, id} ->
          if id == resource_id, do: title
        end)
      ]

    # Clone the resource and its children
    cloned =
      clone_resource_tree(
        source_rev,
        target_project.working_pub,
        target_project.project,
        state.current_author
      )

    # Attach to the target container
    target_container_rev = target_project.rev_by_title[to || "root"]
    target_container_res = %{id: to_id}

    Oli.Seeder.attach_pages_to(
      [cloned.resource],
      target_container_res,
      target_container_rev,
      target_project.working_pub
    )
  end

  defp clone_resource_tree(source_rev, target_pub, target_project, author) do
    # Create a new resource in the target project
    if source_rev.resource_type_id == Oli.Resources.ResourceType.id_for_page() do
      Oli.Seeder.create_page(
        source_rev.title,
        target_pub,
        target_project,
        author
      )
    else
      # Container - recursively clone children
      new_container =
        Oli.Seeder.create_container(
          source_rev.title,
          target_pub,
          target_project,
          author
        )

      # Clone and attach children if any
      if source_rev.children && Enum.any?(source_rev.children) do
        # Would need to implement recursive cloning of children
        # For now, just return the container
      end

      new_container
    end
  end
end
