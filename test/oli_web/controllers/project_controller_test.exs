defmodule OliWeb.ProjectControllerTest do
  use OliWeb.ConnCase
  alias Oli.Repo
  alias Oli.Activities
  alias Oli.Activities.ActivityRegistrationProject
  alias Oli.Interop.Export
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType

  import Oli.Factory

  setup [:author_project_conn]
  @valid_attrs %{title: "default title", slug: "default_title"}
  @invalid_attrs %{title: ""}

  describe "projects" do
    # this test demonstrates the valid case where an author has multiple user accounts associated
    # (consider an authoring account shared across lms or independent instructor accounts)
    test "multiple linked user accounts still renders properly", %{conn: conn, author: author} do
      _user_associated = insert(:user, author: author)
      _user2_associated = insert(:user, author: author)

      conn = get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))

      assert html_response(conn, 200) =~ "Projects"
    end
  end

  describe "overview" do
    test "displays the page", %{conn: conn, project: project} do
      publisher = Oli.Inventories.get_publisher(project.publisher_id)
      custom_act = Activities.get_registration_by_slug("oli_image_coding")

      %ActivityRegistrationProject{}
      |> ActivityRegistrationProject.changeset(%{
        activity_registration_id: custom_act.id,
        project_id: project.id
      })
      |> Repo.insert()

      conn = get(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      response = html_response(conn, 200)
      assert response =~ "Overview"
      assert response =~ project.title
      assert response =~ publisher.name
    end
  end

  describe "triggers" do
    test "enables triggers", %{conn: conn, project: project} do
      refute project.allow_triggers

      conn = post(conn, Routes.project_path(conn, :enable_triggers, project.slug))

      response = html_response(conn, 302)
      assert response =~ "redirected"

      updated_project = Oli.Authoring.Course.get_project!(project.id)
      assert updated_project.allow_triggers
    end
  end

  describe "create project" do
    test "redirects to page index when data is valid", %{conn: conn} do
      conn = post(conn, Routes.project_path(conn, :create), project: @valid_attrs)

      assert html_response(conn, 302) =~
               "/workspaces/course_author/#{@valid_attrs.slug}/overview"
    end

    test "redirects back to workspace when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.project_path(conn, :create), project: @invalid_attrs)
      assert html_response(conn, 302) =~ "/workspaces/course_author"
    end
  end

  describe "export" do
    setup [:admin_conn, :create_project_with_products]

    test "export a project with products works correctly", %{
      project: project,
      product_1: product_1,
      product_2: product_2,
      page_resource_1: page_resource_1,
      page_resource_2: page_resource_2
    } do
      entries =
        Export.export(project)
        |> unzip_to_memory()

      m = Enum.reduce(entries, %{}, fn {f, c}, m -> Map.put(m, f, c) end)

      # There are 7 files in the export (2 resources, 2 products, 1 hierarchy, 1 manifest and 1 project)
      assert length(entries) == 7
      assert Map.has_key?(m, ~c"_hierarchy.json")
      assert Map.has_key?(m, ~c"_media-manifest.json")
      assert Map.has_key?(m, ~c"_project.json")
      assert Map.has_key?(m, ~c"_product-#{product_1.id}.json")
      assert Map.has_key?(m, ~c"_product-#{product_2.id}.json")
      assert Map.has_key?(m, ~c"#{page_resource_1.id}.json")
      assert Map.has_key?(m, ~c"#{page_resource_2.id}.json")
    end

    test "export a project with products works correctly by filtering out products that have publications from other projects.",
         %{
           project: project,
           product_1: product_1,
           product_2: product_2,
           page_resource_1: page_resource_1,
           page_resource_2: page_resource_2
         } do
      create_another_publication(product_2)

      entries =
        Export.export(project)
        |> unzip_to_memory()

      m = Enum.reduce(entries, %{}, fn {f, c}, m -> Map.put(m, f, c) end)

      # There are 6 files in the export (2 resources, 1 product, 1 hierarchy, 1 manifest and 1 project)
      assert length(entries) == 6
      assert Map.has_key?(m, ~c"_hierarchy.json")
      assert Map.has_key?(m, ~c"_media-manifest.json")
      assert Map.has_key?(m, ~c"_project.json")
      assert Map.has_key?(m, ~c"_product-#{product_1.id}.json")
      assert Map.has_key?(m, ~c"#{page_resource_1.id}.json")
      assert Map.has_key?(m, ~c"#{page_resource_2.id}.json")
    end
  end

  defp create_another_publication(product_2) do
    project_2 = insert(:project)
    # Create page 1
    page_resource_3 = insert(:resource)

    page_revision_3 =
      insert(:revision, %{
        objectives: %{},
        resource_type_id: ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page 3",
        resource: page_resource_3,
        slug: "page_3"
      })

    # Associate page 1 to the project
    insert(:project_resource, %{project_id: project_2.id, resource_id: page_resource_3.id})

    # root container
    container_resource_2 = insert(:resource)

    container_revision_2 =
      insert(:revision, %{
        resource: container_resource_2,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: [page_resource_3.id],
        content: %{},
        deleted: false,
        slug: "root_container_2",
        title: "Root Container 2"
      })

    # Associate root container to the project
    insert(:project_resource, %{project_id: project_2.id, resource_id: container_resource_2.id})

    new_publication =
      insert(:publication, %{
        project: project_2,
        root_resource_id: container_resource_2.id
      })

    insert(:published_resource, %{
      publication: new_publication,
      resource: container_resource_2,
      revision: container_revision_2
    })

    insert(:published_resource, %{
      publication: new_publication,
      resource: page_resource_3,
      revision: page_revision_3
    })

    {:ok, product_2} = Sections.create_section_resources(product_2, new_publication)
    Sections.rebuild_contained_pages(product_2)
  end
end
