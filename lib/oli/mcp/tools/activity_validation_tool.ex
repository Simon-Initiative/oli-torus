defmodule Oli.MCP.Tools.ActivityValidationTool do
  @moduledoc """
  MCP tool for validating activity JSON.

  Requires an exact Basic Page activity type. Runs explicit JSON decoding,
  JSON Schema validation, and separate domain validation stages, returning
  stage-specific structured errors without writing content.
  """

  use Anubis.Server.Component, type: :tool

  alias Oli.MCP.ActivityInput
  alias Anubis.Server.Response
  alias Oli.GenAI.Agent.MCPToolRegistry
  alias Oli.MCP.UsageTracker

  # Get field descriptions from MCPToolRegistry at compile time
  @tool_schema MCPToolRegistry.get_tool_schema("activity_validation")
  @activity_json_desc get_in(@tool_schema, ["properties", "activity_json", "description"])

  schema do
    field :activity_json, :string, required: true, description: @activity_json_desc

    field :activity_type_slug, :string,
      required: true,
      description: "Exact activity manifest slug"
  end

  @impl true
  def execute(%{activity_json: activity_json} = params, frame) do
    # Track tool usage
    UsageTracker.track_tool_usage("activity_validation", frame)

    case ActivityInput.validate_json(Map.get(params, :activity_type_slug), activity_json) do
      {:ok, _parsed_model} ->
        {:reply, Response.text(Response.tool(), "Activity JSON is valid"), frame}

      {:error, reason} ->
        UsageTracker.track_tool_usage("activity_validation", frame, "error")
        {:reply, ActivityInput.error_response(reason, "Validation failed: "), frame}
    end
  end
end
