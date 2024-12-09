defmodule OliWeb.Workspaces.CourseAuthor.InsightsLiveTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType

  defp insights_path(project_slug) do
    ~p"/workspaces/course_author/#{project_slug}/insights"
  end

  defp create_elixir_project(%{author: author}) do
    project = insert(:project, authors: [author])

    # revisions...

    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 1",
        duration_minutes: 10
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 2",
        duration_minutes: 15
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 3",
        graded: true,
        purpose: :application
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 4",
        graded: true
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        title: "How to use this course"
      })

    module_2_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [page_3_revision.resource_id],
        title: "Configure your setup"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [
          module_1_revision.resource_id,
          module_2_revision.resource_id
        ],
        title: "Introduction"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        intro_content: %{
          "children" => [
            %{
              "children" => [%{"text" => "Welcome to the best course ever!"}],
              "id" => "3477687079",
              "type" => "p"
            }
          ],
          "type" => "p"
        },
        children: [
          unit_1_revision.resource_id,
          page_4_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        page_1_revision,
        page_2_revision,
        page_3_revision,
        page_4_revision,
        module_1_revision,
        module_2_revision,
        unit_1_revision,
        container_revision
      ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_revision.resource_id,
        published: nil
      })

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # create sections...
    section_1 =
      insert(:section,
        base_project: project,
        title: "The best course ever!",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2,
        type: :enrollable
      )

    section_2 =
      insert(:section,
        base_project: project,
        title: "Another best course ever!",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2,
        type: :enrollable
      )

    # create a product...
    product =
      insert(:section,
        base_project: project,
        title: "The best product ever!",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2
      )

    # build section resources...
    Enum.each([section_1, section_2, product], fn section ->
      {:ok, section} = Sections.create_section_resources(section, publication)
      {:ok, _} = Sections.rebuild_contained_pages(section)
      {:ok, _} = Sections.rebuild_contained_objectives(section)
    end)

    %{
      author: author,
      section_1: section_1,
      project: project,
      publication: publication,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      unit_1: unit_1_revision,
      container_revision: container_revision
    }
  end

  defp create_project_of_another_author(%{}) do
    another_author = insert(:author)
    project = insert(:project, authors: [another_author])

    container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [],
        title: "Root Container"
      })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: container_revision.resource_id
    })

    # publish project
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_revision.resource_id,
        published: nil
      })

    # publish resources
    insert(:published_resource, %{
      publication: publication,
      resource: container_revision.resource,
      revision: container_revision,
      author: another_author
    })

    [project: project]
  end

  describe "author cannot access when is not logged in" do
    test "redirects to new session", %{conn: conn} do
      assert {:error,
              {:redirect,
               %{
                 to: "/authors/log_in"
               }}} =
               live(conn, insights_path("testproject"))
    end
  end

  describe "author can not access projects that do not belong to him" do
    setup [:author_conn, :create_project_of_another_author]

    test "and gets redirected to the projects path", %{conn: conn, project: project} do
      assert {:error,
              {:redirect,
               %{
                 to: "/workspaces/course_author",
                 flash: %{"error" => "You don't have access to that project"}
               }}} =
               live(conn, insights_path(project.slug))
    end
  end

  describe "project insights as author" do
    setup [:author_conn, :create_elixir_project]

    test "loads correctly", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, insights_path(project.slug))

      assert has_element?(view, "h5", "Viewing analytics by activity")
    end

    test "lists all sections and products in corresponding multiselect", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, insights_path(project.slug))

      # sections are listed in the sections multiselect
      assert view
             |> element("#sections-options-container")
             |> render() =~ "The best course ever!"

      assert view
             |> element("#sections-options-container")
             |> render() =~ "Another best course ever!"

      refute view
             |> element("#sections-options-container")
             |> render() =~ "The best product ever!"

      # products are listed in the product multiselect
      refute view
             |> element("#products-options-container")
             |> render() =~ "The best course ever!"

      refute view
             |> element("#products-options-container")
             |> render() =~ "Another best course ever!"

      assert view
             |> element("#products-options-container")
             |> render() =~ "The best product ever!"
    end
  end
end
