defmodule Oli.MCP.Resources.URIBuilderTest do
  use ExUnit.Case, async: true

  alias Oli.MCP.Resources.URIBuilder

  describe "build_*_uri/2" do
    test "builds project URI" do
      uri = URIBuilder.build_project_uri("test-project")
      assert uri == "torus://p/test-project"
    end

    test "builds page URI" do
      uri = URIBuilder.build_page_uri("test-project", "123")
      assert uri == "torus://p/test-project/pages/123"
    end

    test "builds activity URI" do
      uri = URIBuilder.build_activity_uri("test-project", "456")
      assert uri == "torus://p/test-project/activities/456"
    end

    test "builds container URI" do
      uri = URIBuilder.build_container_uri("test-project", "789")
      assert uri == "torus://p/test-project/containers/789"
    end

    test "builds objective URI" do
      uri = URIBuilder.build_objective_uri("test-project", "101")
      assert uri == "torus://p/test-project/objectives/101"
    end

    test "builds hierarchy URI" do
      uri = URIBuilder.build_hierarchy_uri("test-project")
      assert uri == "torus://p/test-project/hierarchy"
    end

    test "builds objectives graph URI" do
      uri = URIBuilder.build_objectives_graph_uri("test-project")
      assert uri == "torus://p/test-project/objectives"
    end
  end

  describe "parse_uri/1" do
    test "parses project URI" do
      uri = "torus://p/test-project"
      assert {:ok, {"test-project", :project, nil}} = URIBuilder.parse_uri(uri)
    end

    test "parses page URI" do
      uri = "torus://p/test-project/pages/123"
      assert {:ok, {"test-project", :page, "123"}} = URIBuilder.parse_uri(uri)
    end

    test "parses activity URI" do
      uri = "torus://p/test-project/activities/456"
      assert {:ok, {"test-project", :activity, "456"}} = URIBuilder.parse_uri(uri)
    end

    test "parses container URI" do
      uri = "torus://p/test-project/containers/789"
      assert {:ok, {"test-project", :container, "789"}} = URIBuilder.parse_uri(uri)
    end

    test "parses objective URI" do
      uri = "torus://p/test-project/objectives/101"
      assert {:ok, {"test-project", :objective, "101"}} = URIBuilder.parse_uri(uri)
    end

    test "parses hierarchy URI" do
      uri = "torus://p/test-project/hierarchy"
      assert {:ok, {"test-project", :hierarchy, nil}} = URIBuilder.parse_uri(uri)
    end

    test "parses objectives graph URI" do
      uri = "torus://p/test-project/objectives"
      assert {:ok, {"test-project", :objectives_graph, nil}} = URIBuilder.parse_uri(uri)
    end

    test "returns error for invalid scheme" do
      uri = "http://p/test-project"
      assert {:error, "Invalid scheme: expected 'torus', got 'http'"} = URIBuilder.parse_uri(uri)
    end

    test "returns error for invalid path" do
      uri = "torus://invalid/path"
      assert {:error, "Invalid path: must start with /p/"} = URIBuilder.parse_uri(uri)
    end

    test "returns error for invalid resource type" do
      uri = "torus://p/test-project/invalid/123"
      assert {:error, "Invalid path format"} = URIBuilder.parse_uri(uri)
    end
  end

  describe "get_mime_type/1" do
    test "returns correct MIME types for all resource types" do
      assert URIBuilder.get_mime_type(:project) == "application/vnd.torus.project+json"
      assert URIBuilder.get_mime_type(:page) == "application/vnd.torus.page+json"
      assert URIBuilder.get_mime_type(:activity) == "application/vnd.torus.activity+json"
      assert URIBuilder.get_mime_type(:container) == "application/vnd.torus.container+json"
      assert URIBuilder.get_mime_type(:objective) == "application/vnd.torus.objective+json"
      assert URIBuilder.get_mime_type(:hierarchy) == "application/vnd.torus.hierarchy+json"
      assert URIBuilder.get_mime_type(:objectives_graph) == "application/vnd.torus.objectives-graph+json"
    end
  end
end