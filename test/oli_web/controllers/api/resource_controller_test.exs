defmodule OliWeb.Api.ResourceControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Resources
  alias Oli.Authoring.Course
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Publishing
  alias Oli.Utils.Time

  describe "GET /api/v1/project/:project/link" do
    setup [:author_conn, :create_project_with_pages]

    test "returns pages with numbering_index sorted by curriculum order", %{
      conn: conn,
      project: project,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3
    } do
      conn =
        get(
          conn,
          "/api/v1/project/#{project.slug}/link"
        )

      assert %{"type" => "success", "pages" => pages} = json_response(conn, 200)

      # Verify all pages have numbering_index
      assert Enum.all?(pages, &Map.has_key?(&1, "numbering_index"))

      # Extract numbering indices and verify they're in order
      numbering_indices =
        pages
        |> Enum.map(& &1["numbering_index"])
        |> Enum.reject(&is_nil/1)

      # Verify pages are sorted by numbering_index (curriculum order)
      assert numbering_indices == Enum.sort(numbering_indices)

      # Verify pages are in the response
      page_titles = Enum.map(pages, & &1["title"])
      assert page_1.title in page_titles
      assert page_2.title in page_titles
      assert page_3.title in page_titles
    end

    test "returns 404 when project does not exist", %{conn: conn} do
      conn =
        get(
          conn,
          "/api/v1/project/non-existent-project/link"
        )

      assert response(conn, 404)
    end

    test "returns 403 when the author cannot access the project", %{conn: conn} do
      other_project = insert(:project)

      conn =
        get(
          conn,
          "/api/v1/project/#{other_project.slug}/link"
        )

      assert response(conn, 403)
    end
  end

  describe "GET /api/v1/project/:project/resource/:resource/learning_objectives" do
    setup [:author_conn]

    test "returns resolved learning objectives for a page before it contains the element", %{
      conn: conn
    } do
      %{project: project, resources: resources, revisions: revisions} =
        create_full_project_with_objectives()

      author = hd(project.authors)

      {:ok, _} =
        Resources.update_revision(revisions.page_revision_2, %{
          author_id: author.id,
          activity_refs: [resources.act_resource_y.id]
        })

      conn =
        conn
        |> log_in_author(author)
        |> get(
          "/api/v1/project/#{project.slug}/resource/#{revisions.page_revision_2.slug}/learning_objectives"
        )

      assert %{"type" => "success", "learningObjectives" => learning_objectives} =
               json_response(conn, 200)

      assert Enum.map(learning_objectives, & &1["resource_id"]) == [
               resources.obj_resource_c.id,
               resources.obj_resource_c1.id
             ]
    end

    test "returns 403 when the author cannot access the project", %{conn: conn} do
      %{project: other_project, revisions: revisions} = create_full_project_with_objectives()

      conn =
        get(
          conn,
          "/api/v1/project/#{other_project.slug}/resource/#{revisions.page_revision_2.slug}/learning_objectives"
        )

      assert response(conn, 403)
    end
  end

  describe "PUT /api/v1/project/:project/resource/:resource" do
    setup [:author_conn, :create_project_with_pages]

    test "returns forbidden when adding a content element for a disabled project feature", %{
      author: author,
      conn: conn,
      project: project,
      page_1: page
    } do
      {:ok, project} =
        Course.update_project(project, %{
          alternatives_enabled: false,
          experiments_enabled: true
        })

      {:ok, alternatives_group} =
        ResourceEditor.create(
          project.slug,
          author,
          Oli.Resources.ResourceType.id_for_alternatives(),
          %{
            title: "Alternatives Group",
            content: %{"options" => [], "strategy" => "user_section_preference"}
          }
        )

      project.slug
      |> Publishing.project_working_publication()
      |> then(&Publishing.get_published_resource!(&1.id, page.resource_id))
      |> Publishing.update_published_resource(%{
        lock_updated_at: Time.now(),
        locked_by_id: author.id
      })

      conn =
        put(conn, "/api/v1/project/#{project.slug}/resource/#{page.slug}", %{
          "update" => %{
            "content" => %{
              "version" => "0.1.0",
              "model" => [
                %{
                  "type" => "alternatives",
                  "id" => "new-alternatives",
                  "alternatives_id" => alternatives_group.resource_id,
                  "children" => []
                }
              ]
            }
          }
        })

      assert response(conn, 403) == "alternatives authoring is not enabled for this project"
    end
  end

  defp create_project_with_pages(%{author: author}) do
    project = insert(:project, authors: [author])

    # Create pages first
    page_1_resource = insert(:resource)

    page_1_revision =
      insert(:revision,
        resource: page_1_resource,
        title: "First Page",
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        deleted: false
      )

    page_2_resource = insert(:resource)

    page_2_revision =
      insert(:revision,
        resource: page_2_resource,
        title: "Second Page",
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        deleted: false
      )

    page_3_resource = insert(:resource)

    page_3_revision =
      insert(:revision,
        resource: page_3_resource,
        title: "Third Page",
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        deleted: false
      )

    # Create root container with pages as children
    container_resource = insert(:resource)

    container_revision =
      insert(:revision,
        resource: container_resource,
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [page_1_resource.id, page_2_resource.id, page_3_resource.id],
        deleted: false
      )

    # Create publication with root container
    publication =
      insert(:publication,
        project: project,
        published: nil,
        root_resource_id: container_resource.id
      )

    # Publish all resources - container first
    insert(:published_resource,
      publication: publication,
      resource: container_resource,
      revision: container_revision
    )

    insert(:published_resource,
      publication: publication,
      resource: page_1_resource,
      revision: page_1_revision
    )

    insert(:published_resource,
      publication: publication,
      resource: page_2_resource,
      revision: page_2_revision
    )

    insert(:published_resource,
      publication: publication,
      resource: page_3_resource,
      revision: page_3_revision
    )

    # Associate resources to project
    insert(:project_resource, project_id: project.id, resource_id: container_resource.id)
    insert(:project_resource, project_id: project.id, resource_id: page_1_resource.id)
    insert(:project_resource, project_id: project.id, resource_id: page_2_resource.id)
    insert(:project_resource, project_id: project.id, resource_id: page_3_resource.id)

    %{
      project: project,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision
    }
  end
end
