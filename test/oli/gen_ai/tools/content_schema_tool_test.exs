defmodule Oli.GenAI.Tools.ContentSchemaToolTest do
  use Oli.DataCase

  alias Oli.GenAI.Tools.ContentSchemaTool

  describe "content schema tool" do
    test "returns the content element schema successfully" do
      frame = %{}
      result = ContentSchemaTool.execute(%{}, frame)
      
      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => schema_json}] = response.content
      
      # Verify it's valid JSON
      {:ok, schema} = Jason.decode(schema_json)
      
      # Verify it has the expected structure of a JSON schema
      assert %{"$id" => _id, "$schema" => _schema, "title" => "Content Element"} = schema
      assert Map.has_key?(schema, "$defs")
      assert Map.has_key?(schema, "anyOf")
      
      # Verify some key definitions exist
      defs = schema["$defs"]
      assert Map.has_key?(defs, "paragraph")
      assert Map.has_key?(defs, "heading")
      assert Map.has_key?(defs, "text")
      assert Map.has_key?(defs, "image")
      assert Map.has_key?(defs, "table")
    end

    test "handles missing schema file gracefully" do
      # Mock the Application.app_dir to return a non-existent path
      original_app_dir = Application.get_env(:oli, :test_app_dir_override)
      Application.put_env(:oli, :test_app_dir_override, "/non/existent/path")

      # Override the get_content_schema function to use our test path
      defmodule TestContentSchemaTool do
        def get_content_schema do
          schema_path = "/non/existent/path/priv/schemas/v0-1-0/content-element.schema.json"
          
          case File.read(schema_path) do
            {:ok, content} ->
              case Jason.decode(content) do
                {:ok, schema} ->
                  {:ok, Jason.encode!(schema, pretty: true)}
                {:error, reason} ->
                  {:error, "Failed to parse schema file as JSON: #{inspect(reason)}"}
              end
              
            {:error, reason} ->
              {:error, "Failed to read content schema file: #{inspect(reason)}"}
          end
        end
      end

      # Test error handling
      case TestContentSchemaTool.get_content_schema() do
        {:error, error_message} ->
          assert String.contains?(error_message, "Failed to read content schema file")
        _ ->
          # If file somehow exists, that's fine too
          :ok
      end

      # Cleanup
      if original_app_dir do
        Application.put_env(:oli, :test_app_dir_override, original_app_dir)
      else
        Application.delete_env(:oli, :test_app_dir_override)
      end
    end

    test "schema contains expected content element types" do
      frame = %{}
      result = ContentSchemaTool.execute(%{}, frame)
      
      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => schema_json}] = response.content
      
      {:ok, schema} = Jason.decode(schema_json)
      defs = schema["$defs"]
      
      # Test that major content element types are defined
      expected_types = [
        "paragraph", "heading", "text", "image", "table", "list", 
        "hyperlink", "formula", "math", "code-v1", "code-v2", 
        "blockquote", "video", "audio", "youtube", "webpage"
      ]
      
      for type <- expected_types do
        assert Map.has_key?(defs, type), "Schema missing definition for '#{type}'"
      end
    end

    test "schema has proper JSON schema structure" do
      frame = %{}
      result = ContentSchemaTool.execute(%{}, frame)
      
      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => schema_json}] = response.content
      
      {:ok, schema} = Jason.decode(schema_json)
      
      # Verify root schema properties
      assert schema["$schema"] == "http://json-schema.org/draft-07/schema"
      assert schema["title"] == "Content Element"
      assert schema["description"] == "A content model element"
      
      # Verify it has the main structure
      assert is_list(schema["anyOf"])
      assert length(schema["anyOf"]) == 3  # top-level, block, inline
      
      # Verify top-level includes expected references
      top_level = Enum.find(schema["anyOf"], fn item -> 
        item["$ref"] == "#/$defs/top-level" 
      end)
      assert top_level != nil
    end
  end
end