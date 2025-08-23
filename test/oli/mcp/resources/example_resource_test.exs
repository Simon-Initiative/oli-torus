defmodule Oli.MCP.Resources.ExampleResourceTest do
  use ExUnit.Case, async: true

  alias Oli.MCP.Resources.ExampleResource

  describe "read/2" do
    test "returns oli_multiple_choice example structure" do
      frame = %{}
      params = %{}

      assert {:reply, response, _frame} = ExampleResource.read(params, frame)

      # Extract and parse the JSON content
      assert %Anubis.Server.Response{contents: %{"text" => json_content}} = response
      assert {:ok, example_data} = Jason.decode(json_content)

      # Verify example structure
      assert Map.has_key?(example_data, "stem")
      assert Map.has_key?(example_data, "choices")
      assert Map.has_key?(example_data, "authoring")

      # Verify choices
      assert is_list(example_data["choices"])
      assert length(example_data["choices"]) == 4

      # Verify stem structure
      stem = example_data["stem"]
      assert Map.has_key?(stem, "id")
      assert Map.has_key?(stem, "content")
      assert stem["id"] == "stem_1"

      # Verify authoring structure
      authoring = example_data["authoring"]
      assert Map.has_key?(authoring, "parts")
      assert is_list(authoring["parts"])
      assert length(authoring["parts"]) == 1

      # Verify first part has responses
      part = hd(authoring["parts"])
      assert Map.has_key?(part, "responses")
      assert is_list(part["responses"])
      assert length(part["responses"]) == 2
    end
  end

  describe "uri/0" do
    test "returns correct URI" do
      assert ExampleResource.uri() == "torus://examples/oli_multiple_choice"
    end
  end

  describe "mime_type/0" do
    test "returns correct MIME type" do
      assert ExampleResource.mime_type() == "application/json"
    end
  end
end
