defmodule Oli.MCP.Resources.ExamplesResourceTest do
  use ExUnit.Case, async: true

  alias Oli.MCP.Resources.ExamplesResource

  describe "read/2" do
    test "returns list of available examples" do
      frame = %{}
      params = %{}

      assert {:reply, response, _frame} = ExamplesResource.read(params, frame)

      # Extract and parse the JSON content  
      assert %Anubis.Server.Response{contents: %{"text" => json_content}} = response
      assert {:ok, examples_data} = Jason.decode(json_content)
      
      # Verify examples list structure
      assert Map.has_key?(examples_data, "examples")
      assert is_list(examples_data["examples"])
      assert length(examples_data["examples"]) == 1
      
      example = hd(examples_data["examples"])
      assert example["type"] == "oli_multiple_choice"
      assert example["name"] == "Multiple Choice"
      assert example["description"] == "Single-select question with multiple options"
      assert example["uri"] == "torus://examples/oli_multiple_choice"
    end
  end

  describe "uri/0" do
    test "returns correct URI" do
      assert ExamplesResource.uri() == "torus://examples"
    end
  end

  describe "mime_type/0" do
    test "returns correct MIME type" do
      assert ExamplesResource.mime_type() == "application/vnd.torus.examples-list+json"
    end
  end
end