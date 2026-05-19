defmodule Oli.Scenarios.Directives.Assert.ReviewAttemptAssertion do
  @moduledoc """
  Handles assertions for student review-attempt visibility.
  """

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Attempts.ReviewPolicy
  alias Oli.Delivery.Page.PageContext
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Directives.Assert.Helpers
  alias Oli.Scenarios.Engine

  def assert(%AssertDirective{review_attempt: review_spec}, state) when is_map(review_spec) do
    with {:ok, section} <- get_section(state, review_spec.section),
         {:ok, student} <- Helpers.get_user(state, review_spec.student),
         {:ok, page_revision} <- get_page_revision(state, section, review_spec.page),
         {:ok, resource_attempt} <-
           get_latest_reviewable_attempt(section, student, page_revision, review_spec.page) do
      page_context =
        PageContext.create_for_review(section.slug, resource_attempt.attempt_guid, student, false)

      allow_review =
        ReviewPolicy.allowed?(resource_attempt.attempt_guid, student, section, page_context)

      verification =
        verify_review_attempt(
          review_spec.section,
          review_spec.page,
          review_spec,
          page_context,
          allow_review
        )

      {:ok, state, verification}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def assert(%AssertDirective{review_attempt: nil}, state), do: {:ok, state, nil}

  defp verify_review_attempt(section_name, page_title, expected, page_context, allow_review) do
    try do
      assert_equal(:allow_review, expected.allow_review, allow_review)

      if allow_review do
        activities = page_context.activities || %{}
        activity_states = decode_activity_states(activities)

        assert_equal(:activity_count, expected.activity_count, map_size(activities))
        assert_equal(:activities_visible, expected.activities_visible, map_size(activities) > 0)

        assert_equal(
          :answers_visible,
          expected.answers_visible,
          answers_visible?(activity_states)
        )

        assert_equal(
          :feedback_visible,
          expected.feedback_visible,
          feedback_visible?(activity_states)
        )

        assert_equal(:scores_visible, expected.scores_visible, scores_visible?(activity_states))
      else
        assert_equal(:activities_visible, expected.activities_visible, false)
        assert_equal(:answers_visible, expected.answers_visible, false)
        assert_equal(:feedback_visible, expected.feedback_visible, false)
        assert_equal(:scores_visible, expected.scores_visible, false)
      end

      %VerificationResult{
        to: section_name,
        passed: true,
        message: "Review attempt state for '#{page_title}' matches expected"
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
    raise "Review attempt field '#{field}' mismatch: expected #{inspect(expected)}, got #{inspect(actual)}"
  end

  defp assert_equal(_field, _expected, _actual), do: :ok

  defp decode_activity_states(activities) do
    activities
    |> Map.values()
    |> Enum.map(fn activity ->
      activity.state
      |> HtmlEntities.decode()
      |> Jason.decode!()
    end)
  end

  defp answers_visible?(activity_states) do
    Enum.any?(activity_states, fn state ->
      state
      |> Map.get("parts", [])
      |> Enum.any?(fn part -> not is_nil(part["response"]) end)
    end)
  end

  defp feedback_visible?(activity_states) do
    Enum.any?(activity_states, fn state ->
      state
      |> Map.get("parts", [])
      |> Enum.any?(fn part -> not is_nil(part["feedback"]) end)
    end)
  end

  defp scores_visible?(activity_states) do
    Enum.any?(activity_states, fn state ->
      not is_nil(state["score"]) or not is_nil(state["outOf"])
    end)
  end

  defp get_section(state, section_name) do
    case Engine.get_section(state, section_name) do
      nil ->
        case Engine.get_product(state, section_name) do
          nil -> {:error, "Section '#{section_name}' not found"}
          section -> {:ok, section}
        end

      section ->
        {:ok, section}
    end
  end

  defp get_page_revision(state, section, page_title) do
    project =
      state.projects
      |> Map.values()
      |> Enum.find(fn built_project ->
        built_project.project.id == section.base_project_id
      end)

    with {:ok, built_project} <- project_found(project, section),
         {:ok, page_rev} <- page_found(built_project, page_title) do
      case DeliveryResolver.from_revision_slug(section.slug, page_rev.slug) do
        nil -> {:error, "Page '#{page_title}' not published in section"}
        published_revision -> {:ok, published_revision}
      end
    end
  end

  defp project_found(nil, section),
    do: {:error, "Source project for section '#{section.name}' not found"}

  defp project_found(project, _section), do: {:ok, project}

  defp page_found(built_project, page_title) do
    case Map.get(built_project.rev_by_title, page_title) do
      nil -> {:error, "Page '#{page_title}' not found in project"}
      revision -> {:ok, revision}
    end
  end

  defp get_latest_reviewable_attempt(section, student, page_revision, page_title) do
    page_revision.resource_id
    |> Core.get_resource_attempt_history(section.slug, student.id)
    |> case do
      nil ->
        {:error, "No attempt history found for page '#{page_title}'"}

      {_access, attempts} ->
        attempts
        |> Enum.filter(&reviewable_attempt?/1)
        |> Enum.sort_by(& &1.attempt_number, :desc)
        |> List.first()
        |> case do
          %ResourceAttempt{} = attempt ->
            {:ok, attempt}

          nil ->
            {:error, "No finalized attempt found for page '#{page_title}'"}
        end
    end
  end

  defp reviewable_attempt?(%ResourceAttempt{lifecycle_state: state})
       when state in [:evaluated, :submitted],
       do: true

  defp reviewable_attempt?(_), do: false
end
