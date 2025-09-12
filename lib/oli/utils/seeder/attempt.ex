defmodule Oli.Utils.Seeder.Attempt do
  import Oli.Utils.Seeder.Utils

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Attempts.PageLifecycle.AttemptState
  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Delivery.Page.PageContext

  def visit_page(
        seeds,
        page_revision,
        section,
        user,
        datashop_session_id,
        tags \\ []
      ) do
    [page_revision, section, user, datashop_session_id] =
      unpack(seeds, [page_revision, section, user, datashop_session_id])

    page_context =
      PageContext.create_for_visit(section, page_revision.slug, user, datashop_session_id)

    resource_attempt =
      case page_context.resource_attempts do
        [resource_attempt | _] -> resource_attempt
        _ -> nil
      end

    seeds
    |> tag(tags[:resource_attempt_tag], resource_attempt)
    |> tag(tags[:attempt_hierarchy_tag], page_context.latest_attempts)
    |> tag(tags[:page_context_tag], page_context)
  end

  def start_scored_assessment(
        seeds,
        page_revision,
        section,
        user,
        datashop_session_id,
        tags \\ []
      ) do
    [page_revision, section, user, datashop_session_id] =
      unpack(seeds, [page_revision, section, user, datashop_session_id])

    Core.track_access(page_revision.resource_id, section.id, user.id)

    effective_settings =
      Oli.Delivery.Settings.get_combined_settings(page_revision, section.id, user.id)

    {:ok, %AttemptState{resource_attempt: resource_attempt, attempt_hierarchy: attempt_hierarchy}} =
      PageLifecycle.start(
        page_revision.slug,
        section.slug,
        datashop_session_id,
        user,
        effective_settings,
        &Oli.Delivery.ActivityProvider.provide/7
      )

    seeds
    |> tag(tags[:resource_attempt_tag], resource_attempt)
    |> tag(tags[:attempt_hierarchy_tag], attempt_hierarchy)
  end

  def submit_attempt_for_activity(
        seeds,
        section,
        activity,
        attempt_hierarchy,
        # create_part_input_fn = fn %PartAttempt -> %StudentInput{input: "answer"} end
        create_part_input_fn,
        datashop_session_id,
        tags \\ []
      ) do
    [section, activity, attempt_hierarchy, datashop_session_id] =
      unpack(seeds, [section, activity, attempt_hierarchy, datashop_session_id])

    {activity_attempt, part_attempts_map} = Map.get(attempt_hierarchy, activity.resource_id)

    part_inputs =
      Enum.map(part_attempts_map, fn {_id, part_attempt} ->
        %{attempt_guid: part_attempt.attempt_guid, input: create_part_input_fn.(part_attempt)}
      end)

    evaluation_result =
      Evaluate.evaluate_activity(
        section.slug,
        activity_attempt.attempt_guid,
        part_inputs,
        datashop_session_id
      )

    seeds
    |> tag(tags[:activity_attempt_tag], activity_attempt)
    |> tag(tags[:evaluation_result_tag], evaluation_result)
  end

  def reset_activity(
        seeds,
        section,
        activity_attempt,
        datashop_session_id
      ) do
    [section, activity_attempt, datashop_session_id] =
      unpack(seeds, [section, activity_attempt, datashop_session_id])

    ActivityLifecycle.reset_activity(
      section.slug,
      activity_attempt.attempt_guid,
      datashop_session_id
    )

    seeds
  end

  def submit_scored_assessment(
        seeds,
        section,
        resource_attempt,
        datashop_session_id
      ) do
    [section, resource_attempt, datashop_session_id] =
      unpack(seeds, [section, resource_attempt, datashop_session_id])

    {:ok, submission_result} =
      PageLifecycle.finalize(
        section.slug,
        resource_attempt.attempt_guid,
        datashop_session_id
      )

    seeds
    |> tag(:submission_result_tag, submission_result)
  end
end
