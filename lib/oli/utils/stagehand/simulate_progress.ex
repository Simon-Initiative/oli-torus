defmodule Oli.Utils.Stagehand.SimulateProgress do
  import Oli.Utils.Seeder.Utils

  alias Oli.Resources.Revision
  alias Oli.Utils.Seeder
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Delivery.Attempts.Core.PartAttempt
  alias Oli.Activities
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Utils.Stagehand.WeightedRandom
  alias Oli.Utils.Stagehand.SimulateProgress

  require Logger

  def simulate_student_working_through_course(section, student, all_pages, datashop_session_id, pct_correct) do
    all_pages
    |> Enum.each(fn page_revision ->
      simulate_student_working_through_page(section, page_revision, student, datashop_session_id, pct_correct)
    end)
  end

  defp simulate_student_working_through_page(section, page_revision, student, datashop_session_id, pct_correct) do
    case page_revision do
      %Revision{graded: true} ->
        %{
          scored_page: page_revision,
          section: section,
          student: student
        }
        |> Seeder.Attempt.visit_page(
          ref(:scored_page),
          ref(:section),
          ref(:student),
          datashop_session_id,
          page_context_tag: :page_context
        )
        |> Seeder.Attempt.start_scored_assessment(
          ref(:scored_page),
          ref(:section),
          ref(:student),
          datashop_session_id,
          resource_attempt_tag: :page_attempt,
          attempt_hierarchy_tag: :page_attempt_hierarchy
        )
        |> Seeder.Attempt.visit_page(
          ref(:scored_page),
          ref(:section),
          ref(:student),
          datashop_session_id,
          page_context_tag: :page_context
        )
        |> then(fn map ->
          case map.page_context do
            %{activities: nil} ->
              # page has no activities
              map

            %{activities: activities, latest_attempts: attempt_hierarchy} ->
              activities
              |> Enum.reduce(map, fn {_id, activity_summary}, acc ->
                  # get attempt and parts map from attempt hierarchy corresponding to this activity
                  found = Enum.find(attempt_hierarchy, fn
                    {_id,
                      {%Oli.Delivery.Attempts.Core.ActivityAttempt{
                        attempt_guid: attempt_guid
                      }, _part_attempts_map}} ->
                      attempt_guid == activity_summary.attempt_guid
                    attempt ->
                      IO.inspect(attempt, label: "Not a supported ActivityAttempt record")

                      false
                  end)

                  case found do
                    {_id, {activity_attempt, part_attempts_map}} ->
                      submit_attempt_for_activity(
                        acc,
                        ref(:section),
                        activity_attempt,
                        part_attempts_map,
                        fn %PartAttempt{attempt_guid: _attempt_guid, part_id: part_id} ->
                          get_randomized_part_response(part_id, activity_attempt.revision, pct_correct)
                        end,
                        datashop_session_id
                      )

                    _ ->
                      acc
                  end
              end)
          end
        end)
        |> Seeder.Attempt.submit_scored_assessment(
          ref(:section),
          ref(:page_attempt),
          datashop_session_id
        )

      _ ->
        Seeder.Attempt.visit_page(
          %{},
          page_revision,
          section,
          student,
          datashop_session_id
        )
    end
  end

  def submit_attempt_for_activity(
        seeds,
        section,
        activity_attempt,
        part_attempts_map,
        # create_part_input_fn = fn %ActivitySummary -> %StudentInput{input: "answer"} end
        create_part_input_fn,
        datashop_session_id,
        tags \\ []
      ) do
    [section, activity_attempt, part_attempts_map, datashop_session_id] =
      unpack(seeds, [section, activity_attempt, part_attempts_map, datashop_session_id])

    part_inputs =
      part_attempts_map
      |> Enum.map(fn {_id, part_attempt} ->
        %{part_id: part_attempt.part_id, attempt_guid: part_attempt.attempt_guid, input: create_part_input_fn.(part_attempt)}
      end)
      # only include parts with valid inputs, ignore parts with nil inputs (unsupported part types)
      |> Enum.filter(fn %{input: input} -> input != nil end)

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

  defp get_randomized_part_response(part_id, activity, pct_correct) do
    type_by_id =
      Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn t, m -> Map.put(m, t.id, t) end)

    activity_type = Map.get(type_by_id, activity.activity_type_id).slug

    case activity_type do
      "oli_multiple_choice" ->
        part_response_for_like_rule(part_id, activity.content["authoring"]["parts"], pct_correct)

      "oli_short_answer" ->
        part_response_for_like_rule(part_id, activity.content["authoring"]["parts"], pct_correct)

      "oli_multi_input" ->
        part_response_for_like_rule(part_id, activity.content["authoring"]["parts"], pct_correct)

      _ ->
        nil
    end
  end

  defp part_response_for_like_rule(part_id, parts, pct_correct) do
    weighted_responses =
      parts
      |> Enum.find(fn part -> part["id"] == part_id end)
      |> then(fn part ->
        part["responses"]
        |> Enum.map(fn response ->
          {parse_from_rule(response["rule"]), selection_weight(response["score"], pct_correct)}
        end)
      end)

    weighted_responses
    |> WeightedRandom.choose()
    |> then(fn selection ->
      %StudentInput{input: selection}
    end)
  end

  defp parse_from_rule(rule) do
    [
      ~r/input like {([^}]+)}/
    ]
    |> Enum.reduce_while("other", fn regex, acc ->
      case Regex.run(regex, rule) do
        [_match, response] ->
          case response do
            ".*" ->
              {:halt, "other"}

            response ->
              {:halt, response}
          end

        _ ->
          {:cont, acc}
      end
    end)
  end

  defp selection_weight(score, pct_correct \\ 1.0) do
    if score > 0 do
      pct_correct
    else
      1.0 - pct_correct
    end
  end

end
