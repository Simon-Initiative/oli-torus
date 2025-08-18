defmodule Oli.MCP.Tools.ActivityValidationTool do
  @moduledoc """
  MCP tool for validating activity JSON.

  This tool allows external AI agents to validate activity JSON content
  using the Oli.Validation module to ensure it meets the expected schema
  and structure requirements.
  """

  use Anubis.Server.Component, type: :tool

  alias Oli.Validation
  alias Anubis.Server.Response
  alias Oli.GenAI.Agent.MCPToolRegistry

  # Get field descriptions from MCPToolRegistry at compile time
  @tool_schema MCPToolRegistry.get_tool_schema("activity_validation")
  @activity_json_desc get_in(@tool_schema, ["properties", "activity_json", "description"])

  schema do
    field :activity_json, :string, required: true, description: @activity_json_desc
  end

  @impl true
  def execute(%{activity_json: activity_json}, frame) do
    case validate_activity_json(activity_json) do
      {:ok, _parsed_model} ->
        {:reply, Response.text(Response.tool(), "Activity JSON is valid"), frame}

      {:error, reason} ->
        error_message = format_error(reason)
        {:reply, Response.error(Response.tool(), "Validation failed: #{error_message}"), frame}
    end
  end

  # Validates activity JSON by decoding and running through Oli.Validation
  defp validate_activity_json(json_string) do
    case Jason.decode(json_string) do
      {:ok, activity_map} ->
        Validation.validate_activity(activity_map)

      {:error, reason} ->
        {:error, "Invalid JSON: #{inspect(reason)}"}
    end
  end

  # Formats validation error messages for display
  defp format_error({path, errors}) when is_binary(path) and is_list(errors) do
    "At #{path}: #{Enum.join(errors, ", ")}"
  end

  defp format_error(error) when is_binary(error) do
    error
  end

  defp format_error(error) do
    inspect(error)
  end
end
