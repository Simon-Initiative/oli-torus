defmodule Oli.Scenarios.Builder do
  @moduledoc """
  Builds Torus project structures from Scenarios definitions.
  """
  alias Oli.Scenarios.Types.{ProjectSpec, Node, BuiltProject}
  alias Oli.Authoring.Course
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.ResourceType

  def build!(%ProjectSpec{title: title, root: root_node, objectives: objectives, tags: tags}, author, _institution) do
    # Use the standard Oli.Authoring.Course.create_project infrastructure
    # that the UI uses when creating projects
    {:ok, project_setup} = Course.create_project(title || "Test Project", author)

    %{
      project: project,
      resource: root_resource,
      resource_revision: root_revision,
      publication: publication
    } = project_setup

    # Update the root revision title to match the spec
    # The standard infrastructure creates "Curriculum" but we want the title from the spec
    root_title = root_node.title || "root"
    {:ok, _} =
      ContainerEditor.edit_page(
        project,
        root_revision.slug,
        %{"title" => root_title, "author_id" => author.id}
      )

    # Get the updated root revision
    updated_root_revision = AuthoringResolver.from_resource_id(project.slug, root_resource.id)

    # Build the hierarchy from the spec using ContainerEditor
    {id_by_title, rev_by_title} =
      build_hierarchy!(
        root_node.children,
        updated_root_revision,
        project,
        author,
        %{root_title => root_resource.id, "root" => root_resource.id},
        %{root_title => updated_root_revision, "root" => updated_root_revision}
      )

    # Get the final root revision after all children have been added
    final_root_rev = AuthoringResolver.from_resource_id(project.slug, root_resource.id)

    # Build objectives if specified
    objectives_by_title = build_objectives!(objectives, project, author)
    
    # Build tags if specified
    tags_by_title = build_tags!(tags, project, author)

    %BuiltProject{
      project: project,
      working_pub: publication,
      root: %{
        resource: root_resource,
        revision: final_root_rev,
        author: author
      },
      id_by_title: id_by_title,
      rev_by_title: rev_by_title |> Map.put("root", final_root_rev) |> Map.put(root_title, final_root_rev),
      objectives_by_title: objectives_by_title,
      tags_by_title: tags_by_title
    }
  end

  defp build_hierarchy!([], _parent_rev, _proj, _author, id_map, rev_map),
    do: {id_map, rev_map}

  defp build_hierarchy!(
         [%Node{type: :page, title: title} | rest],
         parent_rev,
         proj,
         author,
         id_map,
         rev_map
       ) do
    # Use ContainerEditor to create and attach the page
    attrs = %{
      objectives: %{"attached" => []},
      children: [],
      content: %{"version" => "0.1.0", "model" => []},
      title: title,
      graded: false,
      max_attempts: 0,
      resource_type_id: ResourceType.id_for_page()
    }

    {:ok, page_rev} = ContainerEditor.add_new(parent_rev, attrs, author, proj)

    # Parent revision has been updated, so fetch the latest version
    updated_parent_rev = AuthoringResolver.from_resource_id(proj.slug, parent_rev.resource_id)

    build_hierarchy!(
      rest,
      updated_parent_rev,
      proj,
      author,
      Map.put(id_map, title, page_rev.resource_id),
      Map.put(rev_map, title, page_rev)
    )
  end

  defp build_hierarchy!(
         [%Node{type: :container, title: title, children: children} | rest],
         parent_rev,
         proj,
         author,
         id_map,
         rev_map
       ) do
    # Use ContainerEditor to create and attach the container
    attrs = %{
      objectives: %{"attached" => []},
      children: [],
      content: %{},
      title: title,
      graded: false,
      resource_type_id: ResourceType.id_for_container()
    }

    {:ok, cont_rev} = ContainerEditor.add_new(parent_rev, attrs, author, proj)

    # Build children of this container (note: cont_rev is already the latest)
    {id_map_updated, rev_map_updated} =
      build_hierarchy!(children, cont_rev, proj, author, id_map, rev_map)

    # Get the final container revision after all children have been added
    cont_final_rev =
      if Enum.empty?(children) do
        cont_rev
      else
        AuthoringResolver.from_resource_id(proj.slug, cont_rev.resource_id)
      end

    # Parent revision has been updated, so fetch the latest version
    updated_parent_rev = AuthoringResolver.from_resource_id(proj.slug, parent_rev.resource_id)

    # Continue with siblings
    build_hierarchy!(
      rest,
      updated_parent_rev,
      proj,
      author,
      Map.put(id_map_updated, title, cont_rev.resource_id),
      Map.put(rev_map_updated, title, cont_final_rev)
    )
  end

  # Build objectives hierarchy
  defp build_objectives!(nil, _project, _author), do: %{}
  defp build_objectives!([], _project, _author), do: %{}

  defp build_objectives!(objectives, project, author) when is_list(objectives) do
    Enum.reduce(objectives, %{}, fn objective, acc ->
      # Create parent objective
      {:ok, %{revision: parent_rev}} =
        ObjectiveEditor.add_new(%{title: objective.title}, author, project)

      parent_map = Map.put(acc, objective.title, parent_rev)

      # Create sub-objectives if any
      case objective[:children] do
        nil ->
          parent_map

        [] ->
          parent_map

        children when is_list(children) ->
          # Create each sub-objective and attach to parent
          Enum.reduce(children, parent_map, fn child_title, child_acc ->
            {:ok, %{revision: child_rev}} =
              ObjectiveEditor.add_new(%{title: child_title}, author, project, parent_rev.slug)

            Map.put(child_acc, child_title, child_rev)
          end)
      end
    end)
  end
  
  # Build tags (flat list)
  defp build_tags!(nil, _project, _author), do: %{}
  defp build_tags!([], _project, _author), do: %{}
  
  defp build_tags!(tags, project, author) when is_list(tags) do
    Enum.reduce(tags, %{}, fn tag_title, acc ->
      case ResourceEditor.create(
             project.slug,
             author,
             ResourceType.id_for_tag(),
             %{"title" => tag_title, "author_id" => author.id}
           ) do
        {:ok, revision} ->
          Map.put(acc, tag_title, revision)
        
        {:error, reason} ->
          raise "Failed to create tag '#{tag_title}': #{inspect(reason)}"
      end
    end)
  end
end
