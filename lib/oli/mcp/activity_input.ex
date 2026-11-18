defmodule Oli.MCP.ActivityInput do
  @moduledoc "Explicit decode, schema, and domain stages shared by MCP activity entry points."
  alias Anubis.Server.Response
  alias Oli.Validation
  alias Oli.Validation.ActivityDomain.{Issue, Limits}

  @doc "Validates bounded activity JSON in order, preserving the decoded model for creation."
  def validate_json(slug, json) do
    with {:ok, model} <- stage("json", Limits.decode(json)),
         :ok <- stage("schema", Validation.validate_activity_schema(slug, model)),
         :ok <- stage("domain", Validation.validate_activity_domain(slug, model)) do
      {:ok, model}
    end
  end

  @doc "Encodes a stage failure as machine-readable MCP error text."
  def format_error(%{stage: _, errors: _} = error), do: Jason.encode!(error)

  @doc "Builds an MCP error with structured issues and a human-readable text fallback."
  def error_response(%{stage: _, errors: _} = error, prefix) do
    Response.error(Response.tool(), prefix <> format_error(error))
    |> Map.put(:structured_content, error)
  end

  defp stage(_name, :ok), do: :ok
  defp stage(_name, {:ok, model}), do: {:ok, model}

  defp stage(name, {:error, issues}) when is_list(issues) do
    errors =
      issues
      |> Enum.take(100)
      |> Enum.map(fn
        %Issue{} = issue ->
          Map.from_struct(issue)

        {message, path} ->
          %{
            code: "schema_validation_failed",
            path: path,
            message: String.slice(message, 0, 256),
            related_paths: []
          }
      end)

    {:error, %{stage: name, errors: errors}}
  end

  defp stage(name, {:error, _}) do
    {:error,
     %{
       stage: name,
       errors: [
         Issue.new("unsupported_activity_type", [], "No JSON schema registered for activity type")
         |> Map.from_struct()
       ]
     }}
  end
end
