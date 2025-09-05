defmodule Oli.Scenarios.Directives.ActivityHandler do
  @moduledoc """
  Handles create_activity directives for creating activities in projects from TorusDoc YAML.

  This handler uses the default author created by the Engine during initialization.
  If you need to use a specific author, create a `user` directive with type `author`
  before the `create_activity` directive.
  """

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, ActivityDirective}
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.TorusDoc.ActivityConverter
  alias Oli.Activities

  @doc """
  Creates an activity in a project from TorusDoc YAML content.

  Uses the current_author from the ExecutionState, which is set to a default
  author when the Engine initializes. You can override this by creating an
  author user before calling create_activity.

  Returns {:ok, updated_state} on success, {:error, reason} on failure.
  """
  def handle(%ActivityDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, author} <- validate_author(state.current_author),
         {:ok, project_name} <- validate_project_name(directive.project),
         {:ok, built_project} <- get_project(project_name, state),
         {:ok, activity_type} <- validate_activity_type(directive.type),
         {:ok, scope} <- validate_scope(directive.scope),
         {:ok, activity_json} <- parse_and_convert_activity(directive.content, directive.type),
         {:ok, {revision, _resource}} <-
           create_activity(
             built_project,
             activity_type,
             author,
             activity_json,
             scope,
             directive.title
           ) do
      # Store activity reference by {project_name, title} for future directives
      updated_activities =
        Map.put(
          state.activities,
          {project_name, directive.title},
          revision
        )

      # Also store by virtual_id if provided
      updated_virtual_ids =
        if directive.virtual_id do
          Map.put(
            state.activity_virtual_ids,
            {project_name, directive.virtual_id},
            revision
          )
        else
          state.activity_virtual_ids
        end

      {:ok, %{state | activities: updated_activities, activity_virtual_ids: updated_virtual_ids}}
    else
      {:error, reason} ->
        {:error, "Failed to create activity '#{directive.title}': #{inspect(reason)}"}
    end
  end

  # Validate that an author is available
  defp validate_author(nil) do
    {:error,
     "No author available. The Engine should provide a default author, or you can create one with a 'user' directive"}
  end

  defp validate_author(author), do: {:ok, author}

  # Validate that project name is provided
  defp validate_project_name(nil), do: {:error, "Project name is required"}
  defp validate_project_name(name) when is_binary(name), do: {:ok, name}
  defp validate_project_name(_), do: {:error, "Project name must be a string"}

  # Get project from state
  defp get_project(project_name, state) do
    case Map.get(state.projects, project_name) do
      nil -> {:error, "Project '#{project_name}' not found"}
      built_project -> {:ok, built_project}
    end
  end

  # Validate activity type
  defp validate_activity_type(nil), do: {:error, "Activity type is required"}

  defp validate_activity_type(type) when is_binary(type) do
    # Check if the activity type is registered
    case Activities.get_registration_by_slug(type) do
      nil -> {:error, "Unknown activity type: #{type}"}
      registration -> {:ok, registration}
    end
  end

  defp validate_activity_type(_), do: {:error, "Activity type must be a string"}

  # Validate scope
  # Default to embedded
  defp validate_scope(nil), do: {:ok, "embedded"}
  defp validate_scope("embedded"), do: {:ok, "embedded"}
  defp validate_scope("banked"), do: {:ok, "banked"}
  defp validate_scope(scope), do: {:error, "Scope must be 'embedded' or 'banked', got: #{scope}"}

  # Parse TorusDoc YAML content and convert to Torus JSON
  defp parse_and_convert_activity(content, type) when is_binary(content) do
    # Add the type field if not present in the YAML
    yaml_with_type = ensure_activity_type(content, type)

    case ActivityConverter.from_yaml(yaml_with_type) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, "Failed to parse activity YAML: #{reason}"}
    end
  end

  defp parse_and_convert_activity(_, _), do: {:error, "Activity content must be a YAML string"}

  # Ensure the activity YAML has the correct type field
  defp ensure_activity_type(yaml_content, type) do
    # Check if type is already specified in the YAML
    if String.contains?(yaml_content, "type:") do
      yaml_content
    else
      # Prepend the type to the YAML
      "type: \"#{type}\"\n#{yaml_content}"
    end
  end

  # Create the activity in the project
  defp create_activity(built_project, activity_registration, author, activity_json, scope, title) do
    project = built_project.project

    # Extract model and other fields from the JSON
    model = Map.drop(activity_json, ["type", "objectives", "tags", "title"])

    # Get objectives and tags if present
    objectives = get_objectives(activity_json)
    tags = Map.get(activity_json, "tags", [])

    # Use provided title or extract from JSON
    final_title = title || Map.get(activity_json, "title", "Untitled Activity")

    # Create the activity
    case ActivityEditor.create(
           project.slug,
           activity_registration.slug,
           author,
           model,
           objectives,
           scope,
           final_title,
           # objective_map - empty for now
           %{},
           tags
         ) do
      {:ok, {revision, resource}} ->
        {:ok, {revision, resource}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Extract objectives from activity JSON
  defp get_objectives(activity_json) do
    case Map.get(activity_json, "objectives") do
      %{"attached" => objectives} when is_list(objectives) -> objectives
      objectives when is_list(objectives) -> objectives
      _ -> []
    end
  end
end
