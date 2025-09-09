defmodule Oli.MCP.UsageTracker do
  @moduledoc """
  Utility module for tracking MCP usage across tools and resources.

  Provides a centralized way to track tool calls and resource access
  with minimal performance impact.
  """

  alias Oli.MCP.Auth

  @doc """
  Tracks tool usage from within a tool execute callback.

  Extracts the bearer token from the frame and logs the tool usage.
  """
  def track_tool_usage(tool_name, frame, status \\ "success") do
    case get_bearer_token_from_frame(frame) do
      {:ok, token} ->
        Auth.track_usage_by_token(token, "tool",
          tool_name: tool_name,
          status: status
        )

      {:error, _} ->
        # Don't fail the tool call if tracking fails
        :ok
    end
  end

  @doc """
  Tracks resource usage from within a resource read callback.

  Extracts the bearer token from the frame and logs the resource access.
  """
  def track_resource_usage(resource_uri, frame, status \\ "success") do
    case get_bearer_token_from_frame(frame) do
      {:ok, token} ->
        Auth.track_usage_by_token(token, "resource",
          resource_uri: resource_uri,
          status: status
        )

      {:error, _} ->
        # Don't fail the resource access if tracking fails
        :ok
    end
  end

  defp get_bearer_token_from_frame(%{assigns: %{bearer_token: token}}) when is_binary(token) do
    {:ok, token}
  end

  defp get_bearer_token_from_frame(_frame) do
    {:error, :no_token_in_frame}
  end
end
