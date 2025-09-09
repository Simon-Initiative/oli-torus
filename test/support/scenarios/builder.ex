defmodule Oli.Scenarios.Builder do
  @moduledoc """
  Builds Torus project structures from Scenarios definitions.
  """
  alias Oli.Scenarios.Types.{ProjectSpec, Node, BuiltProject}
  alias Oli.Authoring.Course
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.ResourceType

  def build!(%ProjectSpec{title: title, root: root_node}, author, _institution) do
    # Use the standard Oli.Authoring.Course.create_project infrastructure
    # that the UI uses when creating projects
    {:ok, project_setup} = Course.create_project(title || "Test Project", author)

    %{
      project: project,
      resource: root_resource,
      resource_revision: root_revision,
      publication: publication
    } = project_setup

    # Update the root revision title to match what tests expect
    # The standard infrastructure creates "Curriculum" but tests expect "root"
    {:ok, _} =
      ContainerEditor.edit_page(
        project,
        root_revision.slug,
        %{"title" => "root", "author_id" => author.id}
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
        %{"root" => root_resource.id},
        %{"root" => updated_root_revision}
      )

    # Get the final root revision after all children have been added
    final_root_rev = AuthoringResolver.from_resource_id(project.slug, root_resource.id)

    %BuiltProject{
      project: project,
      working_pub: publication,
      root: %{
        resource: root_resource,
        revision: final_root_rev,
        author: author
      },
      id_by_title: id_by_title,
      rev_by_title: Map.put(rev_by_title, "root", final_root_rev)
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
end
