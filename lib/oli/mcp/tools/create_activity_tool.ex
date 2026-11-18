defmodule Oli.MCP.Tools.CreateActivityTool do
  @moduledoc """
  MCP tool for creating activities in projects.

  This tool validates activity JSON and creates activities using the ActivityEditor.create
  function. It requires a system admin author for authorization.
  """

  use Anubis.Server.Component, type: :tool

  alias Oli.MCP.ActivityInput
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Accounts
  alias Anubis.Server.Response
  alias Oli.GenAI.Agent.MCPToolRegistry
  alias Oli.MCP.Auth.Authorization
  alias Oli.MCP.UsageTracker

  # Get field descriptions from MCPToolRegistry at compile time
  @tool_schema MCPToolRegistry.get_tool_schema("create_activity")
  @project_slug_desc get_in(@tool_schema, ["properties", "project_slug", "description"])
  @activity_json_desc get_in(@tool_schema, ["properties", "activity_json", "description"])
  @activity_type_slug_desc get_in(@tool_schema, [
                             "properties",
                             "activity_type_slug",
                             "description"
                           ])

  schema do
    field :project_slug, :string, required: true, description: @project_slug_desc
    field :activity_json, :string, required: true, description: @activity_json_desc
    field :activity_type_slug, :string, required: true, description: @activity_type_slug_desc
  end

  @impl true
  def execute(
        %{
          project_slug: project_slug,
          activity_json: activity_json,
          activity_type_slug: activity_type_slug
        },
        frame
      ) do
    # Track tool usage
    UsageTracker.track_tool_usage("create_activity", frame)

    # Validate project access before proceeding
    case Authorization.validate_project_access(project_slug, frame) do
      {:ok, %{author_id: author_id}} ->
        case create_activity(project_slug, activity_json, activity_type_slug, author_id) do
          {:ok, activity_info} ->
            response_text = format_success_response(activity_info)
            {:reply, Response.text(Response.tool(), response_text), frame}

          {:error, reason} ->
            UsageTracker.track_tool_usage("create_activity", frame, "error")

            response =
              case reason do
                %{stage: _, errors: _} ->
                  ActivityInput.error_response(reason, "Activity creation failed: ")

                _ ->
                  Response.error(
                    Response.tool(),
                    "Activity creation failed: #{format_error(reason)}"
                  )
              end

            {:reply, response, frame}
        end

      {:error, reason} ->
        UsageTracker.track_tool_usage("create_activity", frame, "error")
        {:reply, Response.error(Response.tool(), "Authorization failed: #{reason}"), frame}
    end
  end

  # Creates the activity after validation
  defp create_activity(project_slug, activity_json, activity_type_slug, author_id) do
    with {:ok, activity_model} <- ActivityInput.validate_json(activity_type_slug, activity_json),
         {:ok, author} <- get_author(author_id),
         {:ok, {activity_revision, _content}} <-
           create_activity_in_project(
             project_slug,
             activity_type_slug,
             author,
             activity_model
           ) do
      {:ok,
       %{
         resource_id: activity_revision.resource_id,
         revision_id: activity_revision.id,
         slug: activity_revision.slug,
         title: activity_revision.title
       }}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, inspect(error)}
    end
  end

  # Gets the author by ID
  defp get_author(author_id) do
    case Accounts.get_author(author_id) do
      nil -> {:error, "Author not found: #{author_id}"}
      author -> {:ok, author}
    end
  end

  # Creates the activity using ActivityEditor.create
  defp create_activity_in_project(project_slug, activity_type_slug, author, activity_model) do
    # Extract preview text for title if not specified
    title = get_activity_title(activity_model)

    # ActivityEditor.create expects:
    # create(project_slug, activity_type_slug, author, model, all_parts_objectives, scope, title, objective_map, tags)
    ActivityEditor.create(
      project_slug,
      activity_type_slug,
      author,
      activity_model,
      # all_parts_objectives - empty for now
      [],
      # scope
      "banked",
      title,
      # objective_map - empty for now
      %{},
      # tags - empty for now
      []
    )
  end

  # Extracts title from activity model
  defp get_activity_title(activity_model) do
    case activity_model do
      %{"authoring" => %{"previewText" => preview_text}}
      when is_binary(preview_text) and preview_text != "" ->
        preview_text

      %{"stem" => %{"content" => content}} when is_list(content) ->
        case extract_text_from_content(content) |> String.trim() do
          "" -> "Generated Activity"
          text -> String.slice(text, 0, 50)
        end

      _ ->
        "Generated Activity"
    end
  end

  # Extracts text from Slate-style content structure
  defp extract_text_from_content(content) when is_list(content) do
    content
    |> Enum.map(&extract_text_from_element/1)
    |> Enum.join(" ")
    |> String.trim()
  end

  defp extract_text_from_element(%{"children" => children}) when is_list(children) do
    children
    |> Enum.map(&extract_text_from_node/1)
    |> Enum.join("")
  end

  defp extract_text_from_element(_), do: ""

  defp extract_text_from_node(%{"text" => text}), do: text

  defp extract_text_from_node(%{"children" => children}) when is_list(children) do
    extract_text_from_content(children)
  end

  defp extract_text_from_node(_), do: ""

  # Formats success response as JSON
  defp format_success_response(%{
         resource_id: resource_id,
         revision_id: revision_id,
         slug: slug,
         title: title
       }) do
    response = %{
      "success" => true,
      "message" => "Activity created successfully",
      "activity" => %{
        "resource_id" => resource_id,
        "revision_id" => revision_id,
        "slug" => slug,
        "title" => title
      }
    }

    Jason.encode!(response, pretty: true)
  end

  # Formats error messages
  defp format_error(%{stage: _, errors: _} = error), do: ActivityInput.format_error(error)
  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
