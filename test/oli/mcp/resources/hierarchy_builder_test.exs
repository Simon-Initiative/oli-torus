defmodule Oli.MCP.Resources.HierarchyBuilderTest do
  use ExUnit.Case, async: true

  alias Oli.MCP.Resources.HierarchyBuilder
  alias Oli.Delivery.Hierarchy.HierarchyNode

  describe "build_hierarchy_resource/2" do
    test "converts simple hierarchy node to MCP resource format" do
      project_slug = "test-project"

      # Create a simple hierarchy node structure
      revision = %{
        # Page
        resource_type_id: 1,
        title: "Test Page",
        slug: "test-page"
      }

      node = %HierarchyNode{
        resource_id: 123,
        revision: revision,
        children: []
      }

      result = HierarchyBuilder.build_hierarchy_resource(node, project_slug)

      assert result.resource_uri == "torus://p/test-project/pages/123"
      assert result.resource_id == 123
      assert result.title == "Test Page"
      assert result.resource_type == "page"
      assert result.children == []
    end

    test "converts container node to correct URI and type" do
      project_slug = "test-project"

      revision = %{
        # Container
        resource_type_id: 2,
        title: "Test Container",
        slug: "test-container"
      }

      node = %HierarchyNode{
        resource_id: 456,
        revision: revision,
        children: []
      }

      result = HierarchyBuilder.build_hierarchy_resource(node, project_slug)

      assert result.resource_uri == "torus://p/test-project/containers/456"
      assert result.resource_type == "container"
    end

    test "converts activity node to correct URI and type" do
      project_slug = "test-project"

      revision = %{
        # Activity (>2)
        resource_type_id: 3,
        title: "Test Activity",
        slug: "test-activity"
      }

      node = %HierarchyNode{
        resource_id: 789,
        revision: revision,
        children: []
      }

      result = HierarchyBuilder.build_hierarchy_resource(node, project_slug)

      assert result.resource_uri == "torus://p/test-project/activities/789"
      assert result.resource_type == "activity"
    end

    test "handles nested hierarchy with children" do
      project_slug = "test-project"

      # Parent container
      parent_revision = %{
        # Container
        resource_type_id: 2,
        title: "Parent Container",
        slug: "parent"
      }

      # Child page
      child_revision = %{
        # Page
        resource_type_id: 1,
        title: "Child Page",
        slug: "child"
      }

      child_node = %HierarchyNode{
        resource_id: 456,
        revision: child_revision,
        children: []
      }

      parent_node = %HierarchyNode{
        resource_id: 123,
        revision: parent_revision,
        children: [child_node]
      }

      result = HierarchyBuilder.build_hierarchy_resource(parent_node, project_slug)

      assert result.resource_type == "container"
      assert length(result.children) == 1

      child_result = List.first(result.children)
      assert child_result.resource_uri == "torus://p/test-project/pages/456"
      assert child_result.resource_type == "page"
      assert child_result.title == "Child Page"
    end

    test "handles missing title by using slug" do
      project_slug = "test-project"

      revision = %{
        resource_type_id: 1,
        title: nil,
        slug: "fallback-slug"
      }

      node = %HierarchyNode{
        resource_id: 123,
        revision: revision,
        children: []
      }

      result = HierarchyBuilder.build_hierarchy_resource(node, project_slug)

      assert result.title == "fallback-slug"
    end

    test "handles missing title and slug by using 'Untitled'" do
      project_slug = "test-project"

      revision = %{
        resource_type_id: 1,
        title: nil,
        slug: nil
      }

      node = %HierarchyNode{
        resource_id: 123,
        revision: revision,
        children: []
      }

      result = HierarchyBuilder.build_hierarchy_resource(node, project_slug)

      assert result.title == "Untitled"
    end
  end
end
