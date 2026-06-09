defmodule Oli.Scenarios.Directives.InstructorCustomizationHandler do
  @moduledoc """
  Handles instructor_customization directives by applying section page activity exclusions.
  """

  alias Oli.Delivery.InstructorCustomizations

  alias Oli.Scenarios.DirectiveTypes.{
    ExecutionState,
    InstructorCustomizationDirective,
    VerificationResult
  }

  alias Oli.Scenarios.Directives.AttemptSupport

  def handle(%InstructorCustomizationDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, section} <- AttemptSupport.get_section(state, directive.section),
         {:ok, actor} <- get_actor(state, directive.actor),
         {:ok, page_revision} <-
           AttemptSupport.get_page_revision(state, directive.section, directive.page),
         {:ok, _view} <-
           execute_ops(directive.ops || [], section, page_revision.resource_id, actor, state) do
      verification = %VerificationResult{
        to: directive.section,
        passed: true,
        message: "Instructor customizations applied to '#{directive.page}'"
      }

      {:ok, state, verification}
    else
      {:error, reason} ->
        {:error, "Failed to execute instructor_customization directive: #{format_error(reason)}"}
    end
  end

  defp execute_ops(ops, section, page_resource_id, actor, state) do
    Enum.reduce_while(ops, {:ok, nil}, fn %{action: action, data: data}, _acc ->
      case execute_op(action, data, section, page_resource_id, actor, state) do
        {:ok, view} -> {:cont, {:ok, view}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp execute_op("exclude_activity", data, section, page_resource_id, actor, state) do
    with {:ok, revision} <- get_activity_revision(state, data["activity_virtual_id"]) do
      InstructorCustomizations.exclude_activity(section, page_resource_id, revision.resource_id,
        actor: actor
      )
    end
  end

  defp execute_op("restore_activity", data, section, page_resource_id, actor, state) do
    with {:ok, revision} <- get_activity_revision(state, data["activity_virtual_id"]) do
      InstructorCustomizations.restore_activity(section, page_resource_id, revision.resource_id,
        actor: actor
      )
    end
  end

  defp execute_op("exclude_bank_selection", data, section, page_resource_id, actor, _state) do
    InstructorCustomizations.exclude_bank_selection(
      section,
      page_resource_id,
      data["selection_id"],
      actor: actor
    )
  end

  defp execute_op("restore_bank_selection", data, section, page_resource_id, actor, _state) do
    InstructorCustomizations.restore_bank_selection(
      section,
      page_resource_id,
      data["selection_id"],
      actor: actor
    )
  end

  defp execute_op("exclude_bank_candidate", data, section, page_resource_id, actor, state) do
    with {:ok, revision} <- get_activity_revision(state, data["activity_virtual_id"]) do
      InstructorCustomizations.exclude_bank_candidate(
        section,
        page_resource_id,
        data["selection_id"],
        revision.resource_id,
        actor: actor
      )
    end
  end

  defp execute_op("restore_bank_candidate", data, section, page_resource_id, actor, state) do
    with {:ok, revision} <- get_activity_revision(state, data["activity_virtual_id"]) do
      InstructorCustomizations.restore_bank_candidate(
        section,
        page_resource_id,
        data["selection_id"],
        revision.resource_id,
        actor: actor
      )
    end
  end

  defp get_actor(_state, nil), do: {:error, "instructor_customization requires actor"}

  defp get_actor(%ExecutionState{} = state, actor_name) do
    case Map.get(state.users, actor_name) do
      nil -> {:error, "Actor '#{actor_name}' not found"}
      actor -> {:ok, actor}
    end
  end

  defp get_activity_revision(_state, nil),
    do: {:error, "instructor_customization operation requires activity_virtual_id"}

  defp get_activity_revision(%ExecutionState{} = state, activity_virtual_id) do
    revision =
      Enum.find_value(state.activity_virtual_ids, fn
        {{_project_name, ^activity_virtual_id}, revision} -> revision
        _ -> nil
      end)

    case revision do
      nil -> {:error, "Activity with virtual_id '#{activity_virtual_id}' not found"}
      revision -> {:ok, revision}
    end
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
