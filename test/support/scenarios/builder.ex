defmodule Oli.Scenarios.Builder do
  @moduledoc """
  Builds Torus project structures from Scenarios definitions.
  """
  alias Oli.Scenarios.Types.{ProjectSpec, Node, BuiltProject}
  alias Oli.{Repo, Publishing}
  alias Oli.Authoring.Course.{Project, Family}
  alias Oli.Resources.{Resource, Revision, ResourceType}
  alias Oli.Inventories
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Publishing.AuthoringResolver

  def build!(%ProjectSpec{title: title, root: root_node}, author, _institution) do
    # Create a clean project from scratch
    {:ok, family} =
      Family.changeset(%Family{}, %{
        description: "Test family",
        title: title || "Test Project"
      })
      |> Repo.insert()

    publisher =
      case Inventories.default_publisher() do
        nil ->
          {:ok, pub} =
            Inventories.create_publisher(%{
              name: "Test Publisher",
              email: "test@publisher.com",
              address: "Test Address",
              main_contact: "Test Contact",
              website_url: "https://test.com"
            })

          pub

        pub ->
          pub
      end

    {:ok, project} =
      Project.changeset(%Project{}, %{
        title: title || "Test Project",
        description: "Test project",
        version: "1",
        family_id: family.id,
        publisher_id: publisher.id,
        authors: [author]
      })
      |> Repo.insert()

    # Create the root container resource and revision first (this is the only one we create directly)
    {:ok, root_resource} = Resource.changeset(%Resource{}, %{}) |> Repo.insert()

    # Ensure author has an id
    author_id = if author && Map.has_key?(author, :id), do: author.id, else: nil

    {:ok, root_revision} =
      Revision.changeset(%Revision{}, %{
        resource_id: root_resource.id,
        resource_type_id: ResourceType.id_for_container(),
        title: "Root Container",
        slug: "root",
        author_id: author_id,
        children: []
      })
      |> Repo.insert()

    # Now create the working publication with the root resource
    {:ok, publication} =
      Publishing.create_publication(%{
        project_id: project.id,
        root_resource_id: root_resource.id,
        # nil means it's a working publication
        published: nil,
        description: "Working publication"
      })

    # Publish the root container
    {:ok, _published_resource} =
      Publishing.create_published_resource(%{
        publication_id: publication.id,
        resource_id: root_resource.id,
        revision_id: root_revision.id
      })

    # Build the hierarchy from the spec using ContainerEditor
    {id_by_title, rev_by_title} =
      build_hierarchy!(
        root_node.children,
        root_revision,
        project,
        author,
        %{"root" => root_resource.id},
        %{"root" => root_revision}
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
