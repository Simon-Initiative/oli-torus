defmodule Oli.Scenarios.Directives.Assert.ActivityCustomizationAssertion do
  @moduledoc """
  Handles assertions for persisted instructor activity customization state.
  """

  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Delivery.InstructorCustomizations.PageExclusions
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, ExecutionState, VerificationResult}
  alias Oli.Scenarios.Directives.AttemptSupport

  def assert(%AssertDirective{activity_customization: spec}, %ExecutionState{} = state)
      when is_map(spec) do
    with {:ok, section} <- AttemptSupport.get_section(state, spec.section),
         {:ok, page_revision} <- AttemptSupport.get_page_revision(state, spec.section, spec.page),
         %PageExclusions{} = view <-
           InstructorCustomizations.get_page_exclusion_view(section, page_revision.resource_id),
         :ok <- verify_expectations(view, spec, state) do
      {:ok, state,
       %VerificationResult{
         to: spec.section,
         passed: true,
         message: "Instructor customization state for '#{spec.page}' matches expected"
       }}
    else
      {:error, reason} ->
        {:error, reason}

      {:mismatch, message} ->
        {:ok, state,
         %VerificationResult{
           to: spec.section,
           passed: false,
           message: message
         }}
    end
  end

  def assert(%AssertDirective{activity_customization: nil}, state), do: {:ok, state, nil}

  defp verify_expectations(%PageExclusions{} = view, spec, state) do
    with :ok <- verify_embedded_activities(view, spec.embedded_activities, state),
         :ok <- verify_bank_selections(view, spec.bank_selections),
         :ok <- verify_bank_candidates(view, spec.bank_candidates, state) do
      :ok
    end
  end

  defp verify_embedded_activities(view, expectations, state) do
    Enum.reduce_while(expectations, :ok, fn expectation, :ok ->
      with {:ok, activity_virtual_id} <- required_attr(expectation, "activity_virtual_id"),
           {:ok, expected_enabled?} <- required_attr(expectation, "enabled"),
           {:ok, revision} <- get_activity_revision(state, activity_virtual_id) do
        actual_enabled? = InstructorCustomizations.activity_enabled?(view, revision.resource_id)

        compare_enabled(
          actual_enabled?,
          expected_enabled?,
          "embedded activity '#{activity_virtual_id}'"
        )
      end
      |> case do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp verify_bank_selections(view, expectations) do
    Enum.reduce_while(expectations, :ok, fn expectation, :ok ->
      with {:ok, selection_id} <- required_attr(expectation, "selection_id"),
           {:ok, expected_enabled?} <- required_attr(expectation, "enabled") do
        actual_enabled? = InstructorCustomizations.bank_selection_enabled?(view, selection_id)
        compare_enabled(actual_enabled?, expected_enabled?, "bank selection '#{selection_id}'")
      end
      |> case do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp verify_bank_candidates(view, expectations, state) do
    Enum.reduce_while(expectations, :ok, fn expectation, :ok ->
      with {:ok, selection_id} <- required_attr(expectation, "selection_id"),
           {:ok, activity_virtual_id} <- required_attr(expectation, "activity_virtual_id"),
           {:ok, expected_enabled?} <- required_attr(expectation, "enabled"),
           {:ok, revision} <- get_activity_revision(state, activity_virtual_id) do
        actual_enabled? =
          InstructorCustomizations.bank_candidate_enabled?(
            view,
            selection_id,
            revision.resource_id
          )

        compare_enabled(
          actual_enabled?,
          expected_enabled?,
          "bank candidate '#{activity_virtual_id}' in selection '#{selection_id}'"
        )
      end
      |> case do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp compare_enabled(actual, expected, _label) when actual == expected, do: :ok

  defp compare_enabled(actual, expected, label) do
    {:mismatch,
     "#{label} enabled mismatch: expected #{inspect(expected)}, got #{inspect(actual)}"}
  end

  defp required_attr(map, attr) do
    case Map.get(map, attr) do
      nil -> {:error, "activity_customization expectation requires #{attr}"}
      value -> {:ok, value}
    end
  end

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
end
