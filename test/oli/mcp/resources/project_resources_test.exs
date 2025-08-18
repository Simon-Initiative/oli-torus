defmodule Oli.MCP.Resources.ProjectResourcesTest do
  use ExUnit.Case, async: true
  use Oli.DataCase

  import Oli.Factory
  import Oli.MCPTestHelpers

  alias Oli.MCP.Resources.ProjectResources
  alias Hermes.Server.Frame

  describe "read/2" do
    setup do
      # Ensure system roles exist before creating authors
      Oli.TestHelpers.ensure_system_roles()

      # Create test data
      author = insert(:author)
      project = insert(:project, authors: [author])

      # Create a page resource with content
      page_resource = insert(:resource)

      page_revision =
        insert(:revision, %{
          resource: page_resource,
          resource_type_id: 1, # Ensure this is a page
          title: "Test Page",
          content: %{
            "model" => [
              %{
                "type" => "p",
                "children" => [%{"text" => "This is test content"}]
              }
            ]
          },
          slug: "test-page"
        })

      # Associate page with project
      insert(:project_resource, %{project_id: project.id, resource_id: page_resource.id})

      # Create a working publication (published: nil)
      publication =
        insert(:publication, %{
          project: project,
          root_resource_id: page_resource.id,
          published: nil
        })

      insert(:published_resource, %{
        publication: publication,
        resource: page_resource,
        revision: page_revision
      })

      # Create some objectives for testing
      objective_resource_1 = insert(:resource)
      objective_revision_1 = insert(:revision, %{
        resource: objective_resource_1,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("objective"),
        title: "Learning Objective 1",
        slug: "objective-1",
        children: []
      })

      objective_resource_2 = insert(:resource)
      objective_revision_2 = insert(:revision, %{
        resource: objective_resource_2,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("objective"),
        title: "Learning Objective 2",
        slug: "objective-2",
        children: [objective_resource_1.id]  # This objective has child objective 1
      })

      # Associate objectives with project
      insert(:project_resource, %{project_id: project.id, resource_id: objective_resource_1.id})
      insert(:project_resource, %{project_id: project.id, resource_id: objective_resource_2.id})

      # Add objectives to publication
      insert(:published_resource, %{
        publication: publication,
        resource: objective_resource_1,
        revision: objective_revision_1
      })

      insert(:published_resource, %{
        publication: publication,
        resource: objective_resource_2,
        revision: objective_revision_2
      })

      # Set up MCP authentication context
      setup_mcp_auth_context(author.id, project.id)

      frame = %Frame{}

      %{
        project: project,
        author: author,
        page_resource: page_resource,
        page_revision: page_revision,
        objective_resource_1: objective_resource_1,
        objective_resource_2: objective_resource_2,
        frame: frame
      }
    end

    test "reads project metadata successfully", %{project: project, frame: frame} do
      uri = "torus://p/#{project.slug}"
      
      assert {:reply, response, _frame} = ProjectResources.read(%{"uri" => uri}, frame)
      
      # Extract and parse the JSON content
      assert %Hermes.Server.Response{contents: %{"text" => json_content}} = response
      assert {:ok, metadata} = Jason.decode(json_content)
      
      assert metadata["slug"] == project.slug
      assert metadata["title"] == project.title
      assert metadata["status"] == Atom.to_string(project.status)
    end

    test "reads project hierarchy successfully", %{project: project, frame: frame} do
      uri = "torus://p/#{project.slug}/hierarchy"
      
      assert {:reply, response, _frame} = ProjectResources.read(%{"uri" => uri}, frame)
      
      # Extract and parse the JSON content
      assert %Hermes.Server.Response{contents: %{"text" => json_content}} = response
      assert {:ok, hierarchy} = Jason.decode(json_content)
      
      # Verify hierarchy structure
      assert is_map(hierarchy)
      # Root can be either a page or container depending on setup
      assert hierarchy["resource_type"] in ["page", "container"]
      assert is_list(hierarchy["children"])
    end

    test "reads objectives graph successfully", %{project: project, objective_resource_1: obj1, objective_resource_2: obj2, frame: frame} do
      uri = "torus://p/#{project.slug}/objectives"
      
      assert {:reply, response, _frame} = ProjectResources.read(%{"uri" => uri}, frame)
      
      # Extract and parse the JSON content
      assert %Hermes.Server.Response{contents: %{"text" => json_content}} = response
      assert {:ok, objectives_data} = Jason.decode(json_content)
      
      # Verify objectives structure
      assert is_map(objectives_data)
      assert Map.has_key?(objectives_data, "objectives")
      assert is_list(objectives_data["objectives"])
      
      # Should have our 2 objectives
      objectives = objectives_data["objectives"]
      assert length(objectives) == 2
      
      # Find our specific objectives
      obj1_data = Enum.find(objectives, &(&1["resource_id"] == obj1.id))
      obj2_data = Enum.find(objectives, &(&1["resource_id"] == obj2.id))
      
      # Verify objective 1 structure
      assert obj1_data["title"] == "Learning Objective 1"
      assert obj1_data["resource_uri"] == "torus://p/#{project.slug}/objectives/#{obj1.id}"
      assert obj1_data["children"] == []
      
      # Verify objective 2 structure (has objective 1 as child)
      assert obj2_data["title"] == "Learning Objective 2"
      assert obj2_data["resource_uri"] == "torus://p/#{project.slug}/objectives/#{obj2.id}"
      assert obj2_data["children"] == [obj1.id]
    end

    test "reads page content successfully", %{project: project, page_resource: page_resource, frame: frame} do
      uri = "torus://p/#{project.slug}/pages/#{page_resource.id}"
      
      assert {:reply, response, _frame} = ProjectResources.read(%{"uri" => uri}, frame)
      
      # Extract and parse the JSON content
      assert %Hermes.Server.Response{contents: %{"text" => json_content}} = response
      assert {:ok, page_data} = Jason.decode(json_content)
      
      # Verify page structure
      assert page_data["resource_type"] == "page"
      assert page_data["resource_id"] == page_resource.id
      assert Map.has_key?(page_data, "content")
      assert Map.has_key?(page_data, "title")
    end

    test "reads individual objective successfully", %{project: project, objective_resource_1: objective_resource, frame: frame} do
      uri = "torus://p/#{project.slug}/objectives/#{objective_resource.id}"
      
      assert {:reply, response, _frame} = ProjectResources.read(%{"uri" => uri}, frame)
      
      # Extract and parse the JSON content
      assert %Hermes.Server.Response{contents: %{"text" => json_content}} = response
      assert {:ok, objective_data} = Jason.decode(json_content)
      
      # Verify objective structure
      assert objective_data["resource_type"] == "objective"
      assert objective_data["resource_id"] == objective_resource.id
      assert objective_data["title"] == "Learning Objective 1"
      assert objective_data["slug"] == "objective-1"
      assert Map.has_key?(objective_data, "content")
    end

    test "returns error for invalid URI format", %{frame: frame} do
      uri = "invalid://uri/format"
      
      assert {:error, error, _frame} = ProjectResources.read(%{"uri" => uri}, frame)
      assert error.reason == :resource_not_found
    end

    test "returns error for non-existent project", %{frame: frame} do
      uri = "torus://p/non-existent-project"
      
      assert {:error, error, _frame} = ProjectResources.read(%{"uri" => uri}, frame)
      assert error.reason == :resource_not_found
    end

    test "returns error for non-existent resource", %{project: project, frame: frame} do
      uri = "torus://p/#{project.slug}/pages/999999"
      
      assert {:error, error, _frame} = ProjectResources.read(%{"uri" => uri}, frame)
      assert error.reason == :resource_not_found
    end

    test "returns error for resource type mismatch", %{project: project, page_resource: page_resource, frame: frame} do
      # Try to access the page as an activity (should fail due to type mismatch)
      uri = "torus://p/#{project.slug}/activities/#{page_resource.id}"
      
      assert {:error, error, _frame} = ProjectResources.read(%{"uri" => uri}, frame)
      assert error.reason == :resource_not_found
    end
  end

  describe "resource_templates/0" do
    test "returns all expected resource templates" do
      templates = ProjectResources.resource_templates()
      
      # Should have 7 templates
      assert length(templates) == 7
      
      # Check that all expected URI templates are present
      uri_templates = Enum.map(templates, & &1.uri_template)
      
      expected_templates = [
        "torus://p/{project}",
        "torus://p/{project}/hierarchy",
        "torus://p/{project}/objectives",
        "torus://p/{project}/pages/{id}",
        "torus://p/{project}/activities/{id}",
        "torus://p/{project}/containers/{id}",
        "torus://p/{project}/objectives/{id}"
      ]
      
      for template <- expected_templates do
        assert template in uri_templates
      end
      
      # Verify each template has required fields
      for template_resource <- templates do
        assert template_resource.name
        assert template_resource.description
        assert template_resource.mime_type
        assert template_resource.handler == ProjectResources
      end
    end
  end
end