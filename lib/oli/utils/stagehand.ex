defmodule Oli.Utils.Stagehand do
  @moduledoc """
  Stagehand is a tool for generating fake data for testing and development.

  ## Usage
  Be sure to start your development server in iex mode: `iex -S mix phx.server`

  Then you can use the following commands to generate fake data:

  ```elixir
  # Simulate enrollments for a section
  iex> Oli.Utils.Stagehand.simulate_enrollments("example_section", num_instructors: 3, num_students: 5)

  # Simulate progress for students in a section
  iex> Oli.Utils.Stagehand.simulate_progress("example_section")
  ```
  """

  import Oli.Utils.Seeder.Utils

  alias Oli.Resources.Revision
  alias Oli.Utils.Seeder
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Delivery.Attempts.Core.PartAttempt
  alias Oli.Activities
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate

  @doc """
  Simulates a typical set of enrollments for a section.
  """
  def simulate_enrollments(section_slug, opts \\ []) do
    num_instructors = Keyword.get(opts, :num_instructors, 3)
    num_students = Keyword.get(opts, :num_students, 5)

    case Sections.get_section_by_slug(section_slug) do
      nil ->
        IO.puts("Section not found: #{section_slug}")

      section ->
        map = %{}

        map =
          Enum.reduce(1..num_instructors, map, fn _i, map ->
            Seeder.Section.create_and_enroll_instructor(map, section)
          end)

        map =
          Enum.reduce(1..num_students, map, fn _i, map ->
            Seeder.Section.create_and_enroll_learner(map, section)
          end)

        IO.puts("User enrollment creation complete")

        map
    end
  end

  @doc """
  Simulates progress for students in a given section.
  """
  def simulate_progress(section_slug, opts \\ []) do
    chunk_size = Keyword.get(opts, :chunk_size, 10)

    students =
      Sections.fetch_students(section_slug)
      |> Enum.map(fn student -> {student, UUID.uuid4()} end)

    section = Sections.get_section_by_slug(section_slug)
    all_pages = Sections.fetch_all_pages(section_slug)

    # students
    # |> Enum.chunk_every(chunk_size)
    # |> Enum.map(fn chunk ->
    #   chunk
    #   |> Enum.map(fn {student, datashop_session_id} ->
    #     Task.async(fn ->
    #       simulate_student_working_through_course(
    #         section,
    #         student,
    #         all_pages,
    #         datashop_session_id
    #       )
    #     end)
    #   end)
    #   |> Task.await_many()
    # end)
    students
    |> Enum.map(fn {student, datashop_session_id} ->
      simulate_student_working_through_course(
        section,
        student,
        all_pages,
        datashop_session_id
      )
    end)
  end

  defp simulate_student_working_through_course(section, student, all_pages, datashop_session_id) do
    all_pages
    |> Enum.each(fn page_revision ->
      simulate_student_working_through_page(section, page_revision, student, datashop_session_id)
    end)
  end

  defp simulate_student_working_through_page(section, page_revision, student, datashop_session_id) do
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
        |> then(fn map ->
          case map.page_context do
            %{activities: nil} ->
              # page has no activities
              IO.inspect(map, label: "no activities found")

              map

            %{activities: activities, latest_attempts: attempt_hierarchy} ->
              activities
              |> Enum.reduce(map, fn {_id, activity_summary}, acc ->
                # get attempt and parts map from attempt hierarchy corresponding to this activity
                {_id, {activity_attempt, part_attempts_map}} =
                  Enum.find(attempt_hierarchy, fn {_id,
                                                   {%Oli.Delivery.Attempts.Core.ActivityAttempt{
                                                      attempt_guid: attempt_guid
                                                    }, _part_attempts_map}} ->
                    attempt_guid == activity_summary.attempt_guid
                  end)

                IO.inspect(activity_attempt, label: "processing activity_attempt")

                submit_attempt_for_activity(
                  acc,
                  ref(:section),
                  activity_attempt,
                  part_attempts_map,
                  fn %PartAttempt{attempt_guid: attempt_guid, part_id: part_id} ->
                    %{
                      attempt_guid: attempt_guid,
                      input: get_randomized_part_response(part_id, activity_attempt.revision)
                    }
                  end,
                  datashop_session_id
                )
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

  defp get_randomized_part_response(part_id, activity) do
    type_by_id =
      Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn t, m -> Map.put(m, t.id, t) end)

    activity_type = Map.get(type_by_id, activity.activity_type_id).slug

    case activity_type do
      "oli_multiple_choice" ->
        part_response_for_like_rule(part_id, activity.content["authoring"]["parts"])

      "oli_short_answer" ->
        part_response_for_like_rule(part_id, activity.content["authoring"]["parts"])

      "oli_multi_input" ->
        part_response_for_like_rule(part_id, activity.content["authoring"]["parts"])

      _ ->
        "incorrect"
    end
  end

  defp part_response_for_like_rule(part_id, parts) do
    weighted_responses =
      parts
      |> Enum.find(fn part -> part["id"] == part_id end)
      |> then(fn part ->
        part["responses"]
        |> Enum.map(fn response ->
          {parse_from_rule(response["rule"]), selection_weight(response["score"])}
        end)
      end)

    IO.inspect(weighted_responses, label: "part_response_for_like_rule: weighted_responses")

    weighted_responses
    |> weight_based_selection()
    |> then(fn selection ->
      %StudentInput{input: selection}
    end)
  end

  defp parse_from_rule(rule) do
    # TODO: not every rule is a like rule
    IO.inspect(rule, label: "parse_from_rule")

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

  defp selection_weight(score, p_correct \\ 0.8) do
    if score > 0 do
      p_correct
    else
      1.0 - p_correct
    end
  end

  def weight_based_selection(items) do
    marker =
      items
      |> Enum.reduce(0, &acc_weight/2)
      |> Kernel.*(:rand.uniform())

    Enum.reduce_while(items, marker, &item_below_marker/2)
  end

  defp item_below_marker({_name, weight}, acc) when weight < acc,
    do: {:cont, acc - weight}

  defp item_below_marker({name, _weight}, _acc),
    do: {:halt, name}

  defp acc_weight({_, weight}, total),
    do: total + weight
end
