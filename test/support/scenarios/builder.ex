defmodule Oli.Scenarios.Builder do
  @moduledoc """
  Builds Torus project structures from Scenarios definitions.
  """
  alias Oli.Scenarios.Types.{ProjectSpec, Node, BuiltProject}
  alias Oli.{Repo, Publishing, Seeder}
  alias Oli.Authoring.Course.{Project, Family}
  alias Oli.Resources.{Resource, Revision, ResourceType}
  alias Oli.Inventories

  def build!(%ProjectSpec{title: title, root: root_node}, author, _institution) do
    # Create a clean project from scratch
    {:ok, family} = Family.changeset(%Family{}, %{
      description: "Test family",
      title: title || "Test Project"
    }) |> Repo.insert()
    
    publisher = case Inventories.default_publisher() do
      nil ->
        {:ok, pub} = Inventories.create_publisher(%{
          name: "Test Publisher",
          email: "test@publisher.com",
          address: "Test Address",
          main_contact: "Test Contact",
          website_url: "https://test.com"
        })
        pub
      pub -> pub
    end
    
    {:ok, project} = Project.changeset(%Project{}, %{
      title: title || "Test Project",
      description: "Test project",
      version: "1",
      family_id: family.id,
      publisher_id: publisher.id,
      authors: [author]
    }) |> Repo.insert()
    
    # Create the root container resource and revision first
    {:ok, root_resource} = Resource.changeset(%Resource{}, %{}) |> Repo.insert()
    
    # Ensure author has an id
    author_id = if author && Map.has_key?(author, :id), do: author.id, else: nil
    
    {:ok, root_revision} = Revision.changeset(%Revision{}, %{
      resource_id: root_resource.id,
      resource_type_id: ResourceType.id_for_container(),
      title: "Root Container",
      slug: "root",
      author_id: author_id,
      children: []
    }) |> Repo.insert()
    
    # Now create the working publication with the root resource
    {:ok, publication} = Publishing.create_publication(%{
      project_id: project.id,
      root_resource_id: root_resource.id,
      published: nil,  # nil means it's a working publication
      description: "Working publication"
    })
    
    # Publish the root container
    {:ok, _published_resource} = Publishing.create_published_resource(%{
      publication_id: publication.id,
      resource_id: root_resource.id,
      revision_id: root_revision.id
    })
    
    # Build the hierarchy from the spec
    {id_by_title, rev_by_title, final_root_rev} = 
      build_hierarchy!(
        root_node.children, 
        root_resource, 
        root_revision,
        publication, 
        project, 
        author,
        %{"root" => root_resource.id},
        %{"root" => root_revision}
      )

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

  defp build_hierarchy!([], _parent_res, parent_rev, _pub, _proj, _author, id_map, rev_map),
    do: {id_map, rev_map, parent_rev}

  defp build_hierarchy!([%Node{type: :page, title: title} | rest], parent_res, parent_rev, pub, proj, author, id_map, rev_map) do
    %{resource: page_res, revision: page_rev} = 
      Seeder.create_page(title, pub, proj, author)
    
    # attach_pages_to returns the updated parent revision
    updated_parent_rev = Seeder.attach_pages_to([page_res], parent_res, parent_rev, pub)
    
    build_hierarchy!(
      rest, parent_res, updated_parent_rev, pub, proj, author,
      Map.put(id_map, title, page_res.id),
      Map.put(rev_map, title, page_rev)
    )
  end

  defp build_hierarchy!([%Node{type: :container, title: title, children: children} | rest], parent_res, parent_rev, pub, proj, author, id_map, rev_map) do
    %{resource: cont_res, revision: cont_rev} = 
      Seeder.create_container(title, pub, proj, author)
    
    # attach_pages_to returns the updated parent revision
    updated_parent_rev = Seeder.attach_pages_to([cont_res], parent_res, parent_rev, pub)

    # Build children of this container
    {id_map_updated, rev_map_updated, cont_final_rev} =
      build_hierarchy!(children, cont_res, cont_rev, pub, proj, author, id_map, rev_map)

    # Continue with siblings
    build_hierarchy!(
      rest, parent_res, updated_parent_rev, pub, proj, author,
      Map.put(id_map_updated, title, cont_res.id),
      Map.put(rev_map_updated, title, cont_final_rev)  # Store the final container revision with its children
    )
  end
end