defmodule Oli.Scenarios.Directives.CloneHandler do
  @moduledoc """
  Handles clone directives to duplicate existing projects.
  """

  alias Oli.Scenarios.DirectiveTypes.CloneDirective
  alias Oli.Scenarios.Engine
  alias Oli.Authoring.Clone

  def handle(%CloneDirective{from: from, name: name, title: title}, state) do
    try do
      # Get the source project from state
      source = Engine.get_project(state, from)

      if source == nil do
        {:error, "Source project '#{from}' not found for cloning"}
      else
        # Clone the project using Oli's clone functionality
        # Clone.clone_project always adds " Copy" suffix, so we'll update the title after
        case Clone.clone_project(source.project.slug, state.current_author) do
          {:ok, cloned_project} ->
            # Update the title if a specific one was requested
            cloned_project =
              if title do
                {:ok, updated_project} =
                  Oli.Authoring.Course.update_project(cloned_project, %{title: title})

                updated_project
              else
                cloned_project
              end

            # Get the full project structure for the cloned project
            # We need to build a BuiltProject structure similar to what Builder creates
            publication = Oli.Publishing.project_working_publication(cloned_project.slug)
            root_revision = Oli.Publishing.AuthoringResolver.root_container(cloned_project.slug)

            # Build the id and revision maps
            {id_by_title, rev_by_title} = build_resource_maps(cloned_project.slug, root_revision)

            built_project = %Oli.Scenarios.Types.BuiltProject{
              project: cloned_project,
              working_pub: publication,
              root: %{
                # We don't need the resource for clone
                resource: nil,
                revision: root_revision,
                author: state.current_author
              },
              id_by_title: id_by_title,
              rev_by_title: Map.put(rev_by_title, "root", root_revision),
              # For now, leave empty
              objectives_by_title: %{},
              # For now, leave empty
              tags_by_title: %{}
            }

            # Store the cloned project in state
            new_state = Engine.put_project(state, name, built_project)

            {:ok, new_state}

          {:error, reason} ->
            {:error, "Failed to clone project '#{from}': #{inspect(reason)}"}
        end
      end
    rescue
      e ->
        {:error, "Failed to clone project '#{from}': #{Exception.message(e)}"}
    end
  end

  defp build_resource_maps(project_slug, root_revision) do
    # Recursively build maps of resource IDs and revisions by title
    build_maps_recursive(project_slug, root_revision, %{}, %{})
  end

  defp build_maps_recursive(project_slug, revision, id_map, rev_map) do
    # Add current revision to maps
    id_map = Map.put(id_map, revision.title, revision.resource_id)
    rev_map = Map.put(rev_map, revision.title, revision)

    # Process children if this is a container
    case revision.children do
      nil ->
        {id_map, rev_map}

      [] ->
        {id_map, rev_map}

      children ->
        Enum.reduce(children, {id_map, rev_map}, fn child_id, {id_acc, rev_acc} ->
          child_rev = Oli.Publishing.AuthoringResolver.from_resource_id(project_slug, child_id)
          build_maps_recursive(project_slug, child_rev, id_acc, rev_acc)
        end)
    end
  end
end
