defmodule Oli.GenAI.Agent.MCPToolRegistry do
  @moduledoc """
  Registry that provides MCP tools to the ToolBroker in a standardized format.

  This avoids duplication by mapping MCP tool definitions to ToolBroker format
  and providing execution through the actual MCP tool modules.
  """

  require Logger

  @doc """
  Returns all MCP tools converted to ToolBroker format.
  """
  @spec get_all_tools() :: [map()]
  def get_all_tools do
    tool_definitions()
    |> Enum.map(fn {_name, tool} -> tool end)
  end

  @doc """
  Get schema for a specific tool by name.
  """
  @spec get_tool_schema(String.t()) :: map() | nil
  def get_tool_schema(tool_name) do
    case Map.get(tool_definitions(), tool_name) do
      nil -> nil
      tool -> tool.schema
    end
  end

  @doc """
  Get field definitions for a specific tool to use in Hermes schema macro.
  """
  @spec get_tool_fields(String.t()) :: [tuple()] | nil
  def get_tool_fields(tool_name) do
    case get_tool_schema(tool_name) do
      nil -> nil
      schema -> convert_schema_to_fields(schema)
    end
  end

  # Private function containing all tool definitions
  defp tool_definitions do
    %{
      "revision_content" => %{
        name: "revision_content",
        desc: "Retrieve JSON content of a resource revision from any project",
        schema: %{
          "type" => "object",
          "properties" => %{
            "project_slug" => %{
              "type" => "string",
              "description" => "The slug of the project containing the revision"
            },
            "revision_slug" => %{
              "type" => "string",
              "description" => "The slug of the revision to retrieve content from"
            }
          },
          "required" => ["project_slug", "revision_slug"]
        }
      },
      "activity_validation" => %{
        name: "activity_validation",
        desc: "Validate activity JSON content against schema requirements",
        schema: %{
          "type" => "object",
          "properties" => %{
            "activity_json" => %{
              "type" => "string",
              "description" => "JSON string containing the activity to validate"
            }
          },
          "required" => ["activity_json"]
        }
      },
      "activity_test_eval" => %{
        name: "activity_test_eval",
        desc: "Test activity evaluation by simulating student responses",
        schema: %{
          "type" => "object",
          "properties" => %{
            "activity_type" => %{
              "type" => "string",
              "description" => "The activity type slug (e.g., 'oli_multiple_choice')"
            },
            "activity_json" => %{
              "type" => "string",
              "description" => "JSON string containing the activity model to test"
            },
            "part_inputs" => %{
              "type" => "string",
              "description" =>
                "JSON encoded string of a list of objects containing part inputs to evaluate"
            }
          },
          "required" => ["activity_type", "activity_json", "part_inputs"]
        }
      },
      "example_activity" => %{
        name: "example_activity",
        desc: "Retrieve example activities by type to understand structure",
        schema: %{
          "type" => "object",
          "properties" => %{
            "activity_type" => %{
              "type" => "string",
              "description" =>
                "The activity type slug (e.g., 'oli_multiple_choice', 'oli_short_answer')"
            }
          },
          "required" => ["activity_type"]
        }
      },
      "create_activity" => %{
        name: "create_activity",
        desc: "Create activities in projects using validated activity JSON",
        schema: %{
          "type" => "object",
          "properties" => %{
            "project_slug" => %{
              "type" => "string",
              "description" => "The project slug where the activity will be created"
            },
            "activity_json" => %{
              "type" => "string",
              "description" => "JSON string containing the activity model to create"
            },
            "activity_type_slug" => %{
              "type" => "string",
              "description" => "The activity type slug (e.g., 'oli_multiple_choice')"
            }
          },
          "required" => ["project_slug", "activity_json", "activity_type_slug"]
        }
      },
      "content_schema" => %{
        name: "content_schema",
        desc: "Retrieve the JSON schema for rich content elements",
        schema: %{
          "type" => "object",
          "properties" => %{},
          "required" => []
        }
      }
    }
  end

  # Converts JSON schema format to Hermes field tuples
  defp convert_schema_to_fields(schema) do
    properties = Map.get(schema, "properties", %{})
    required_fields = Map.get(schema, "required", [])

    Enum.map(properties, fn {field_name, field_spec} ->
      field_atom = String.to_atom(field_name)

      field_type =
        case Map.get(field_spec, "type") do
          "string" -> :string
          "integer" -> :integer
          "boolean" -> :boolean
          # default to string
          _ -> :string
        end

      opts = []
      opts = if field_name in required_fields, do: [{:required, true} | opts], else: opts

      opts =
        if desc = Map.get(field_spec, "description"),
          do: [{:description, desc} | opts],
          else: opts

      {field_atom, field_type, opts}
    end)
  end

  @doc """
  Executes an MCP tool by name with the given arguments.
  """
  @spec execute_mcp_tool(String.t(), map(), map()) :: {:ok, term()} | {:error, String.t()}
  def execute_mcp_tool(tool_name, args, _ctx) do
    case find_mcp_tool_module(tool_name) do
      nil ->
        {:error, "MCP tool '#{tool_name}' not found"}

      module when not is_nil(module) and is_atom(module) ->
        try do
          # Convert args to the format expected by MCP tools (atom keys)
          mcp_args = convert_args_to_atoms(args)

          # Execute the MCP tool
          # Note: We pass a mock frame since we're calling this directly
          case module.execute(mcp_args, %{}) do
            {:reply, response, _frame} ->
              case response do
                # Handle Hermes.Server.Response struct
                %Hermes.Server.Response{isError: true, content: content} when is_list(content) ->
                  error_text =
                    content
                    |> Enum.filter(&(Map.get(&1, "type") == "text"))
                    |> Enum.map(&Map.get(&1, "text"))
                    |> Enum.join(" ")

                  {:error, error_text}

                %Hermes.Server.Response{isError: false, content: content} when is_list(content) ->
                  # Extract text content from MCP response
                  text_content =
                    content
                    |> Enum.filter(&(Map.get(&1, "type") == "text"))
                    |> Enum.map(&Map.get(&1, "text"))
                    |> Enum.join(" ")

                  {:ok, %{content: text_content, token_cost: estimate_tokens(text_content)}}

                %Hermes.Server.Response{} = hermes_response ->
                  # Fallback for other Hermes response types
                  content_text = inspect(hermes_response.content)
                  {:ok, %{content: content_text, token_cost: estimate_tokens(content_text)}}

                # Legacy response formats
                %{text: text} ->
                  {:ok, %{content: text, token_cost: estimate_tokens(text)}}

                %{error: error} ->
                  {:error, error}

                %{isError: true, content: content} when is_list(content) ->
                  # Handle MCP error response format
                  error_text =
                    content
                    |> Enum.filter(&(Map.get(&1, "type") == "text"))
                    |> Enum.map(&Map.get(&1, "text"))
                    |> Enum.join(" ")

                  {:error, error_text}

                other ->
                  Logger.warning("Unexpected MCP response format: #{inspect(other)}")
                  {:error, "Unexpected tool response format"}
              end

            other ->
              Logger.warning("Unexpected MCP tool response: #{inspect(other)}")
              {:error, "Unexpected tool response format"}
          end
        rescue
          e ->
            Logger.error("MCP tool execution failed: #{Exception.message(e)}")
            {:error, "Tool execution failed: #{Exception.message(e)}"}
        end

      invalid_module ->
        Logger.error("Invalid module returned for tool '#{tool_name}': #{inspect(invalid_module)}")
        {:error, "Invalid tool module for '#{tool_name}'"}
    end
  end

  # Private functions

  defp find_mcp_tool_module(tool_name) do
    case tool_name do
      "revision_content" -> Oli.GenAI.Tools.RevisionContentTool
      "activity_validation" -> Oli.GenAI.Tools.ActivityValidationTool
      "activity_test_eval" -> Oli.GenAI.Tools.ActivityTestEvalTool
      "example_activity" -> Oli.GenAI.Tools.ExampleActivityTool
      "create_activity" -> Oli.GenAI.Tools.CreateActivityTool
      "content_schema" -> Oli.GenAI.Tools.ContentSchemaTool
      _ -> nil
    end
  end

  defp convert_args_to_atoms(args) when is_map(args) do
    args
    |> Enum.into(%{}, fn {key, value} ->
      atom_key = if is_binary(key), do: String.to_atom(key), else: key

      # Handle special cases where MCP tools expect JSON strings
      converted_value =
        case {atom_key, value} do
          {:activity_json, val} when is_map(val) ->
            # If activity_json is a map, encode it as JSON string
            case Jason.encode(val) do
              {:ok, json_string} -> json_string
              {:error, _} -> inspect(val)
            end

          {_, val} ->
            val
        end

      {atom_key, converted_value}
    end)
  end

  defp estimate_tokens(content) when is_binary(content) do
    # Rough estimate: ~4 characters per token
    div(String.length(content), 4)
  end

  defp estimate_tokens(_), do: 10

  @doc """
  Helper function to get field definitions for a tool that can be used in schema block.
  """
  def schema_fields_for(tool_name) do
    case get_tool_fields(tool_name) do
      nil -> raise "Unknown tool: #{tool_name}"
      fields -> fields
    end
  end
end
