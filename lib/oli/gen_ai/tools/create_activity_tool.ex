defmodule Oli.GenAI.Tools.CreateActivityTool do
  @moduledoc """
  MCP tool for creating activities in projects.

  This tool validates activity JSON and creates activities using the ActivityEditor.create
  function. It requires a system admin author for authorization.
  """

  use Hermes.Server.Component, type: :tool

  alias Oli.Validation
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Accounts
  alias Oli.Accounts.SystemRole
  alias Hermes.Server.Response

  import Ecto.Query

  schema do
    field :project_slug, :string, required: true, description: "The project slug where the activity will be created"
    field :activity_json, :string, required: true, description: "JSON string containing the activity model to create"
    field :activity_type_slug, :string, required: true, description: "The activity type slug (e.g., 'oli_multiple_choice')"
  end

  @impl true
  def execute(%{project_slug: project_slug, activity_json: activity_json, activity_type_slug: activity_type_slug}, frame) do
    case create_activity(project_slug, activity_json, activity_type_slug) do
      {:ok, activity_info} ->
        response_text = format_success_response(activity_info)
        {:reply, Response.text(Response.tool(), response_text), frame}

      {:error, reason} ->
        error_message = format_error(reason)
        {:reply, Response.error(Response.tool(), "Activity creation failed: #{error_message}"), frame}
    end
  end

  # Creates the activity after validation
  defp create_activity(project_slug, activity_json, activity_type_slug) do
    with {:ok, activity_model} <- validate_activity_json(activity_json),
         {:ok, admin_author} <- get_system_admin_author(),
         {:ok, {activity_revision, _content}} <- create_activity_in_project(project_slug, activity_type_slug, admin_author, activity_model) do
      {:ok, %{
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

  # Validates the activity JSON
  defp validate_activity_json(activity_json) do
    with {:ok, activity_model} <- Jason.decode(activity_json),
         {:ok, _parsed_model} <- Validation.validate_activity(activity_model) do
      {:ok, activity_model}
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error, "Invalid JSON: #{Exception.message(error)}"}
      {:error, reason} ->
        {:error, "Activity validation failed: #{format_validation_error(reason)}"}
      error ->
        {:error, "Validation error: #{inspect(error)}"}
    end
  end

  # Gets the first system admin author
  defp get_system_admin_author do
    system_admin_role_id = SystemRole.role_id().system_admin

    query = from(author in Accounts.Author,
      where: author.system_role_id == ^system_admin_role_id,
      limit: 1
    )

    case Oli.Repo.one(query) do
      nil -> {:error, "No system admin author found"}
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
      [], # all_parts_objectives - empty for now
      "banked", # scope
      title,
      %{}, # objective_map - empty for now
      [] # tags - empty for now
    )
  end

  # Extracts title from activity model
  defp get_activity_title(activity_model) do
    case activity_model do
      %{"authoring" => %{"previewText" => preview_text}} when is_binary(preview_text) and preview_text != "" ->
        preview_text
      %{"stem" => %{"content" => content}} when is_list(content) ->
        extract_text_from_content(content) |> String.slice(0, 50)
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

  # Formats validation error messages
  defp format_validation_error({path, errors}) when is_binary(path) and is_list(errors) do
    "At #{path}: #{Enum.join(errors, ", ")}"
  end
  defp format_validation_error(error) when is_binary(error), do: error
  defp format_validation_error(error), do: inspect(error)

  # Formats success response as JSON
  defp format_success_response(%{resource_id: resource_id, revision_id: revision_id, slug: slug, title: title}) do
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
  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
