defmodule Oli.Scenarios.Activities.NullLogicHooks do
  @moduledoc """
  Hook functions for testing activity bank selections with null logic conditions.
  This module provides hooks to manipulate activity bank logic for testing edge cases.
  """

  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Repo
  require Logger

  @doc """
  Nullifies the logic conditions in activity bank selections on the Test Page.
  This simulates corrupted or invalid data scenarios where logic conditions might be null.
  """
  def nil_logic(%ExecutionState{} = state) do
    modify_selection_logic(state, "Nullifying logic conditions", fn selection ->
      Map.put(selection, "logic", %{"conditions" => nil})
    end)
  end

  @doc """
  Sets the entire logic attribute to nil (not just conditions).
  This tests an extreme edge case where the logic structure itself is nil.
  """
  def set_logic_nil(%ExecutionState{} = state) do
    modify_selection_logic(state, "Setting entire logic to nil", fn selection ->
      Map.put(selection, "logic", nil)
    end)
  end

  @doc """
  Alternative hook that completely removes logic from activity banks.
  This tests an even more extreme edge case.
  """
  def remove_logic(%ExecutionState{} = state) do
    modify_selection_logic(state, "Removing logic key", fn selection ->
      Map.delete(selection, "logic")
    end)
  end

  # Common helper function that handles all the boilerplate
  defp modify_selection_logic(%ExecutionState{} = state, action_description, transform_fn) do
    Logger.info("#{action_description} in activity bank selections...")

    with {:ok, section} <- get_section(state),
         {:ok, built_project} <- get_project(state),
         {:ok, project_page_revision} <- get_page_revision(built_project),
         {:ok, section_revision} <- get_section_revision(section, project_page_revision) do
      Logger.info(
        "Found section revision #{section_revision.id} for resource #{project_page_revision.resource_id}"
      )

      # Use PageContent.map to traverse and update the content structure
      updated_content =
        Oli.Resources.PageContent.map(section_revision.content, fn element ->
          case element do
            %{"type" => "selection"} = selection ->
              Logger.info("Found selection element, #{String.downcase(action_description)}")
              transform_fn.(selection)

            other ->
              other
          end
        end)

      # Direct database update to the SECTION's revision
      # This bypasses normal validation and change tracking
      case Repo.transaction(fn ->
             section_revision
             |> Ecto.Changeset.change(%{content: updated_content})
             |> Repo.update!()
           end) do
        {:ok, _updated_revision} ->
          Logger.info("Successfully modified activity bank selection logic in section revision")
          state

        {:error, reason} ->
          Logger.error("Failed to update section revision: #{inspect(reason)}")
          state
      end
    else
      {:error, message} ->
        Logger.error(message)
        state
    end
  end

  defp get_section(state) do
    case Map.get(state.sections, "null_logic_section") do
      nil -> {:error, "Section 'null_logic_section' not found in state"}
      section -> {:ok, section}
    end
  end

  defp get_project(state) do
    case Map.get(state.projects, "null_logic_project") do
      nil -> {:error, "Project 'null_logic_project' not found in state"}
      project -> {:ok, project}
    end
  end

  defp get_page_revision(built_project) do
    case Map.get(built_project.rev_by_title, "Test Page") do
      nil -> {:error, "Page 'Test Page' not found in project"}
      revision -> {:ok, revision}
    end
  end

  defp get_section_revision(section, project_page_revision) do
    case Oli.Publishing.DeliveryResolver.from_resource_id(
           section.slug,
           project_page_revision.resource_id
         ) do
      nil ->
        {:error,
         "Could not find published revision for resource_id #{project_page_revision.resource_id} in section #{section.slug}"}

      revision ->
        {:ok, revision}
    end
  end
end
