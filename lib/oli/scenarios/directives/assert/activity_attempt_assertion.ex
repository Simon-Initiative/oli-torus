defmodule Oli.Scenarios.Directives.Assert.ActivityAttemptAssertion do
  @moduledoc """
  Handles assertions for learner activity attempt state within an active page attempt.
  """

  alias Oli.Delivery.Attempts.ActivityAttemptState
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Directives.Assert.Helpers

  def assert(%AssertDirective{activity_attempt: activity_spec}, state)
      when is_map(activity_spec) do
    with {:ok, _section} <- Helpers.get_section(state, activity_spec.section),
         {:ok, _student} <- Helpers.get_user(state, activity_spec.student),
         {:ok, resource_attempt} <- get_active_resource_attempt(state, activity_spec),
         {:ok, activity_revision} <-
           get_activity_revision(state, activity_spec.activity_virtual_id),
         {:ok, activity_state} <-
           ActivityAttemptState.for_activity(
             resource_attempt,
             activity_revision.resource_id,
             activity_spec.part_id
           ) do
      verification =
        verify_activity_attempt(
          activity_spec.section,
          activity_spec.activity_virtual_id,
          activity_spec,
          activity_state
        )

      {:ok, state, verification}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def assert(%AssertDirective{activity_attempt: nil}, state), do: {:ok, state, nil}

  defp get_active_resource_attempt(state, spec) do
    key = {spec.student, spec.section, spec.page}

    case Map.get(state.page_attempts, key) do
      nil ->
        {:error, "No active attempt found - student must visit page first"}

      {:not_started, _} ->
        {:error, "Page not started - cannot inspect activity attempt"}

      {_status, %{resource_attempt: resource_attempt}} ->
        {:ok, resource_attempt}

      {_status, _unexpected} ->
        {:error, "Stored page attempt does not contain a resource attempt"}
    end
  end

  defp get_activity_revision(state, activity_virtual_id) do
    activity_revision =
      Enum.find_value(state.activity_virtual_ids, fn
        {{_project_name, ^activity_virtual_id}, revision} -> revision
        _ -> nil
      end)

    case activity_revision do
      nil -> {:error, "Activity with virtual_id '#{activity_virtual_id}' not found"}
      revision -> {:ok, revision}
    end
  end

  defp verify_activity_attempt(section_name, activity_virtual_id, expected, actual) do
    try do
      assert_equal(
        :activity_lifecycle_state,
        expected.activity_lifecycle_state,
        actual.activity_lifecycle_state
      )

      assert_equal(
        :part_lifecycle_state,
        expected.part_lifecycle_state,
        actual.part_lifecycle_state
      )

      assert_equal(:score, expected.score, actual.activity_score)
      assert_equal(:out_of, expected.out_of, actual.activity_out_of)
      assert_equal(:part_score, expected.part_score, actual.part_score)
      assert_equal(:part_out_of, expected.part_out_of, actual.part_out_of)
      assert_equal(:answerable, expected.answerable, actual.answerable)

      if expected.response_present do
        assert_response(expected.response, actual.response)
      end

      %VerificationResult{
        to: section_name,
        passed: true,
        message: "Activity attempt state for '#{activity_virtual_id}' matches expected"
      }
    rescue
      e ->
        %VerificationResult{
          to: section_name,
          passed: false,
          message: Exception.message(e)
        }
    end
  end

  defp assert_equal(_field, nil, _actual), do: :ok

  defp assert_equal(field, expected, actual) when expected != actual do
    raise "Activity attempt field '#{field}' mismatch: expected #{inspect(expected)}, got #{inspect(actual)}"
  end

  defp assert_equal(_field, _expected, _actual), do: :ok

  defp assert_response(nil, actual) when actual in [nil, %{}], do: :ok

  defp assert_response(expected, %{"input" => actual}) when is_binary(expected),
    do: assert_response(expected, actual)

  defp assert_response(expected, actual) when expected != actual do
    raise "Activity attempt field 'response' mismatch: expected #{inspect(expected)}, got #{inspect(actual)}"
  end

  defp assert_response(_expected, _actual), do: :ok
end
