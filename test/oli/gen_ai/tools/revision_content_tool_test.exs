defmodule Oli.GenAI.Tools.RevisionContentToolTest do
  use ExUnit.Case, async: true
  use Oli.DataCase

  import Oli.Factory

  alias Oli.GenAI.Tools.RevisionContentTool
  alias Hermes.Server.Frame

  describe "RevisionContentTool" do
    setup do
      # Create test data
      author = insert(:author)
      project = insert(:project, authors: [author])
      
      # Create a page resource with content
      page_resource = insert(:resource)
      page_revision = insert(:revision, %{
        resource: page_resource,
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
      publication = insert(:publication, %{
        project: project, 
        root_resource_id: page_resource.id,
        published: nil
      })
      
      insert(:published_resource, %{
        publication: publication,
        resource: page_resource,
        revision: page_revision,
        author: author
      })

      %{
        project: project,
        page_revision: page_revision,
        author: author,
        publication: publication
      }
    end

    test "execute/2 successfully retrieves revision content", %{project: project, page_revision: page_revision} do
      frame = %Frame{}
      params = %{project_slug: project.slug, revision_slug: page_revision.slug}

      assert {:reply, response, ^frame} = RevisionContentTool.execute(params, frame)
      
      # The response should be a properly formatted Hermes response
      assert %Hermes.Server.Response{} = response
      assert response.type == :tool
      assert response.isError == false
      
      # Should contain the JSON content in the first content item
      [content_item] = response.content
      assert content_item["type"] == "text"
      json_text = content_item["text"]
      assert json_text =~ "This is test content"
      assert json_text =~ "\"type\": \"p\""
    end

    test "execute/2 returns error for non-existent project" do
      frame = %Frame{}
      params = %{project_slug: "non-existent-project", revision_slug: "test-page"}

      assert {:reply, response, ^frame} = RevisionContentTool.execute(params, frame)
      
      # Should be an error response
      assert %Hermes.Server.Response{} = response
      assert response.type == :tool
      assert response.isError == true
      
      [content_item] = response.content
      error_text = content_item["text"]
      assert error_text =~ "Revision not found"
      assert error_text =~ "non-existent-project"
    end

    test "execute/2 returns error for non-existent revision", %{project: project} do
      frame = %Frame{}
      params = %{project_slug: project.slug, revision_slug: "non-existent-page"}

      assert {:reply, response, ^frame} = RevisionContentTool.execute(params, frame)
      
      # Should be an error response
      assert %Hermes.Server.Response{} = response
      assert response.type == :tool
      assert response.isError == true
      
      [content_item] = response.content
      error_text = content_item["text"]
      assert error_text =~ "Revision not found"
      assert error_text =~ "non-existent-page"
    end

    test "execute/2 returns error for deleted revision", %{project: project, publication: publication} do
      # Create a deleted revision
      deleted_resource = insert(:resource)
      deleted_revision = insert(:revision, %{
        resource: deleted_resource,
        deleted: true,
        slug: "deleted-page"
      })
      
      insert(:project_resource, %{project_id: project.id, resource_id: deleted_resource.id})
      
      # Use the working publication for the deleted revision
      insert(:published_resource, %{
        publication: publication,
        resource: deleted_resource,
        revision: deleted_revision,
        author: insert(:author)
      })

      frame = %Frame{}
      params = %{project_slug: project.slug, revision_slug: deleted_revision.slug}

      assert {:reply, response, ^frame} = RevisionContentTool.execute(params, frame)
      
      # Should be an error response
      assert %Hermes.Server.Response{} = response
      assert response.type == :tool
      assert response.isError == true
      
      [content_item] = response.content
      error_text = content_item["text"]
      assert error_text =~ "Revision has been deleted"
    end

    test "execute/2 handles complex content structure", %{project: project, publication: publication} do
      # Create revision with complex content
      complex_resource = insert(:resource)
      complex_revision = insert(:revision, %{
        resource: complex_resource,
        slug: "complex-page",
        content: %{
          "model" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Paragraph with "}, %{"text" => "bold", "strong" => true}, %{"text" => " text"}]
            },
            %{
              "type" => "img",
              "src" => "/images/test.png",
              "alt" => "Test image"
            }
          ],
          "version" => "0.1.0"
        }
      })
      
      insert(:project_resource, %{project_id: project.id, resource_id: complex_resource.id})
      
      # Use the working publication
      insert(:published_resource, %{
        publication: publication,
        resource: complex_resource,
        revision: complex_revision,
        author: insert(:author)
      })

      frame = %Frame{}
      params = %{project_slug: project.slug, revision_slug: complex_revision.slug}

      assert {:reply, response, ^frame} = RevisionContentTool.execute(params, frame)
      
      # Should contain the complex content
      assert %Hermes.Server.Response{} = response
      assert response.type == :tool
      assert response.isError == false
      
      [content_item] = response.content
      json_text = content_item["text"]
      assert json_text =~ "bold"
      assert json_text =~ "Test image"
      assert json_text =~ "0.1.0"
    end
  end
end