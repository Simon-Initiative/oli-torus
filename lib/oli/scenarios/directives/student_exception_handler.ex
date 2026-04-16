defmodule Oli.Scenarios.Directives.StudentExceptionHandler do
  @moduledoc """
  Handles assessment settings student_exception directives.
  """

  alias Oli.Delivery.Settings.StudentExceptions
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, StudentExceptionDirective}
  alias Oli.Scenarios.Engine

  def handle(%StudentExceptionDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, user} <- get_user(state, directive.student),
         {:ok, section} <- get_section(state, directive.section),
         {:ok, page_revision} <- get_page_revision(state, directive.section, directive.page),
         {:ok, _result} <- apply_action(directive, section, page_revision.resource_id, user.id) do
      {:ok, state}
    else
      {:error, reason} -> {:error, "Failed to apply student exception: #{reason}"}
    end
  end

  defp apply_action(
         %StudentExceptionDirective{action: :set, set: attrs},
         section,
         resource_id,
         user_id
       ) do
    StudentExceptions.set_exception(section, resource_id, user_id, attrs || %{})
  end

  defp apply_action(%StudentExceptionDirective{action: :remove}, section, resource_id, user_id) do
    StudentExceptions.remove_exception(section, resource_id, user_id)
  end

  defp get_user(state, user_name) do
    case Map.get(state.users, user_name) do
      nil -> {:error, "User '#{user_name}' not found"}
      user -> {:ok, user}
    end
  end

  defp get_section(state, section_name) do
    case Engine.get_section(state, section_name) do
      nil -> {:error, "Section '#{section_name}' not found"}
      section -> {:ok, section}
    end
  end

  defp get_page_revision(state, section_name, page_title) do
    with {:ok, section} <- get_section(state, section_name),
         {:ok, project} <- get_project_for_section(state, section),
         {:ok, page_rev} <- get_page_from_project(project, page_title) do
      case DeliveryResolver.from_revision_slug(section.slug, page_rev.slug) do
        nil -> {:error, "Page '#{page_title}' not published in section"}
        published_revision -> {:ok, published_revision}
      end
    end
  end

  defp get_project_for_section(state, section) do
    project =
      state.projects
      |> Map.values()
      |> Enum.find(fn built_project ->
        built_project.project.id == section.base_project_id
      end)

    case project do
      nil -> {:error, "Source project for section not found"}
      built_project -> {:ok, built_project}
    end
  end

  defp get_page_from_project(built_project, page_title) do
    case Map.get(built_project.rev_by_title, page_title) do
      nil -> {:error, "Page '#{page_title}' not found in project"}
      revision -> {:ok, revision}
    end
  end
end
