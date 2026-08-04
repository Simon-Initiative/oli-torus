defmodule Oli.Scenarios.Directives.EditAdaptivePageHandler do
  @moduledoc """
  Handles edit_adaptive_page directives, converting an existing page into an
  adaptive (advancedDelivery) page whose deck references an adaptive activity
  created earlier in the scenario via create_activity with a virtual_id.
  """

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, EditAdaptivePageDirective}

  def handle(%EditAdaptivePageDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, author} <- validate_author(state.current_author),
         {:ok, built_project} <- get_project(directive.project, state),
         {:ok, page_revision} <- get_page_revision(built_project, directive.page),
         {:ok, activity_revision} <- get_activity_revision(directive, state),
         content <- adaptive_page_content(activity_revision.resource_id, directive),
         {:ok, new_revision} <-
           update_page(built_project, page_revision, author, content, directive.graded) do
      updated_built_project = %{
        built_project
        | rev_by_title: Map.put(built_project.rev_by_title, directive.page, new_revision)
      }

      updated_projects = Map.put(state.projects, directive.project, updated_built_project)
      {:ok, %{state | projects: updated_projects}}
    else
      {:error, reason} ->
        {:error, "Failed to edit adaptive page '#{directive.page}': #{inspect(reason)}"}
    end
  end

  defp validate_author(nil),
    do: {:error, "No author available. The Engine should provide a default author"}

  defp validate_author(author), do: {:ok, author}

  defp get_project(nil, _state), do: {:error, "Project name is required"}

  defp get_project(project_name, state) do
    case Map.get(state.projects, project_name) do
      nil -> {:error, "Project '#{project_name}' not found"}
      built_project -> {:ok, built_project}
    end
  end

  defp get_page_revision(built_project, page_title) do
    case Map.get(built_project.rev_by_title, page_title) do
      nil -> {:error, "Page '#{page_title}' not found in project"}
      revision -> {:ok, revision}
    end
  end

  defp get_activity_revision(%{activity_virtual_id: nil}, _state),
    do: {:error, "activity_virtual_id is required"}

  defp get_activity_revision(directive, state) do
    case Map.get(state.activity_virtual_ids, {directive.project, directive.activity_virtual_id}) do
      nil ->
        {:error,
         "Activity with virtual_id '#{directive.activity_virtual_id}' not found in project '#{directive.project}'"}

      revision ->
        if Oli.Activities.AdaptiveParts.adaptive_activity?(revision) do
          {:ok, revision}
        else
          {:error,
           "Activity '#{directive.activity_virtual_id}' is not an oli_adaptive activity; " <>
             "edit_adaptive_page requires an adaptive activity"}
        end
    end
  end

  defp adaptive_page_content(activity_resource_id, directive) do
    %{
      "advancedDelivery" => true,
      "advancedAuthoring" => true,
      "displayApplicationChrome" => false,
      "custom" => %{
        "contentMode" => "standard",
        "defaultScreenHeight" => 540,
        "defaultScreenWidth" => 1000,
        "enableHistory" => true,
        "maxScore" => 0,
        "responsiveLayout" => false,
        "themeId" => "torus-default-light",
        "totalScore" => 0
      },
      "additionalStylesheets" => ["/css/delivery_adaptive_themes_default_light.css"],
      "model" => [
        %{
          "id" => "adaptive_group_1",
          "type" => "group",
          "layout" => "deck",
          "children" => [
            %{
              "type" => "activity-reference",
              "activity_id" => activity_resource_id,
              "custom" => %{
                "sequenceId" => "screen_#{directive.activity_virtual_id}",
                "sequenceName" => directive.page
              }
            }
          ]
        }
      ]
    }
  end

  defp update_page(built_project, page_revision, author, content, graded) do
    attrs = %{
      content: content,
      graded: graded == true,
      author_id: author.id
    }

    case Oli.Resources.update_revision(page_revision, attrs) do
      {:ok, updated_revision} ->
        case Oli.Publishing.project_working_publication(built_project.project.slug) do
          nil ->
            {:ok, updated_revision}

          publication ->
            with {:ok, _} <-
                   Oli.Publishing.upsert_published_resource(publication, updated_revision) do
              {:ok, updated_revision}
            end
        end

      error ->
        error
    end
  end
end
