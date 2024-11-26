defmodule OliWeb.Delivery.ActivityHelpers do
  @moduledoc """
  Common helper functions for rendering activities with metrics
  in the instructor dashboard's Insights View (Scored Activities, Practice Activities and Surveys)
  """

  use OliWeb, :html

  alias Oli.Analytics.Summary
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.ManualGrading.RenderedActivity

  def get_activities(assessment_resource_id, section_id, student_ids, filter_by_survey \\ false),
    do:
      Core.get_evaluated_activities_for(
        assessment_resource_id,
        section_id,
        student_ids,
        filter_by_survey
      )

  @spec get_activities_details(
          any(),
          atom() | %{:analytics_version => any(), :id => any(), optional(any()) => any()},
          any(),
          any()
        ) :: any()
  def get_activities_details(activity_resource_ids, section, activity_types_map, page_resource_id) do
    multiple_choice_type_id =
      Enum.find_value(activity_types_map, fn {k, v} -> if v.title == "Multiple Choice", do: k end)

    single_response_type_id =
      Enum.find_value(activity_types_map, fn {k, v} -> if v.title == "Single Response", do: k end)

    multi_input_type_id =
      Enum.find_value(activity_types_map, fn {k, v} ->
        if v.title == "Multi Input",
          do: k
      end)

    likert_type_id =
      Enum.find_value(activity_types_map, fn {k, v} -> if v.title == "Likert", do: k end)

    activity_attempts = Core.get_activity_attempts_by(section.id, activity_resource_ids)

    if section.analytics_version == :v2 do
      response_summaries =
        Summary.get_response_summary_for(page_resource_id, section.id, activity_resource_ids)

      Enum.map(activity_attempts, fn activity_attempt ->
        case activity_attempt.activity_type_id do
          ^multiple_choice_type_id ->
            add_choices_frequencies(activity_attempt, response_summaries)

          ^single_response_type_id ->
            add_single_response_details(activity_attempt, response_summaries)

          ^multi_input_type_id ->
            add_multi_input_details(activity_attempt, response_summaries)

          ^likert_type_id ->
            add_likert_details(activity_attempt, response_summaries)

          _ ->
            activity_attempt
        end
      end)
    else
      activity_attempts
    end
  end

  attr :activity, :map, required: true

  def rendered_activity(
        %{
          activity: %{
            preview_rendered: ["<oli-likert-authoring" <> _rest],
            analytics_version: :v2
          }
        } = assigns
      ) do
    spec =
      VegaLite.from_json("""
      {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "padding": {"left": 5, "top": 10, "right": 5, "bottom": 10},
        "description": "Likert Scale Ratings Distributions and Medians.",
        "datasets": {
          "medians": #{Jason.encode!(assigns.activity.datasets.medians)},
          "values": #{Jason.encode!(assigns.activity.datasets.values)}
        },
        "data": {"name": "medians"},
        "title": {
          "text": #{Jason.encode!(assigns.activity.datasets.title)},
          "offset": 20,
          "fontSize": 20
        },
        "width": 600,
        "height": #{60 + 30 * assigns.activity.datasets.questions_count},
        "encoding": {
          "y": {
            "field": "question",
            "type": "nominal",
            "sort": null,
            "axis": {
              "domain": false,
              "labels": false,
              "offset": #{50 + max(String.length(assigns.activity.datasets.first_choice_text) - 7, 0) * 5},
              "ticks": false,
              "grid": true,
              "title": null
            }
          },
          "x": {
            "type": "quantitative",
            "scale": {"domain": [0, #{to_string(length(assigns.activity.datasets.axis_values) + 1)}]},
            "axis": {
              "grid": false,
              "values": #{Jason.encode!(assigns.activity.datasets.axis_values)},
              "title": null
            }
          }
        },
        "view": {"stroke": null},
        "layer": [
          {
            "mark": {"type": "circle"},
            "data": {"name": "values"},
            "encoding": {
              "x": {"field": "value"},
              "size": {
                "aggregate": "count",
                "type": "quantitative",
                "title": "Number of Ratings",
                "legend": {
                  "offset": #{75 + max(String.length(assigns.activity.datasets.last_choice_text) - 7, 0) * 5}
                }
              },
              "color": {
                "value": "#0165DA"
              },
              "tooltip": [
                {"field": "choice", "type": "nominal", "title": "Rating"},
                {"field": "value", "type": "quantitative", "aggregate": "count", "title": "# Answers"},
                {"field": "out_of", "type": "nominal", "title": "Out of"}
              ]
            }
          },
          {
            "mark": "tick",
            "encoding": {
              "x": {"field": "median"},
              "color": {
                "value": "black"
              },
              "tooltip": [{"field": "median", "type": "quantitative", "title": "Median"}]
            }
          },
          {
            "mark": {"type": "text", "x": -5, "align": "right"},
            "encoding": {
              "text": {"field": "lo"},
              "color": {
                "value": "black"
              }
            }
          },
          {
            "mark": {"type": "text", "x": 605, "align": "left"},
            "encoding": {
              "text": {"field": "hi"},
              "color": {
                "value": "black"
              }
            }
          },
          {
            "transform": [
              {
                "calculate": "length(datum.question) > 30 ? substring(datum.question, 0, 30) + '…' : datum.question",
                "as": "maybe_truncated_question"
              }
            ],
            "mark": {
              "type": "text",
              "align": "right",
              "baseline": "middle",
              "dx": #{-50 - max(String.length(assigns.activity.datasets.first_choice_text) - 7, 0) * 5},
              "fontSize": 13,
              "fontWeight": "bold"
            },
            "encoding": {
              "y": {
                "field": "question",
                "type": "nominal",
                "sort": null
              },
              "x": {
                "value": 0
              },
              "text": {
                "field": "maybe_truncated_question"
              },
              "tooltip": {
                "condition": {
                  "test": "length(datum.question) > 30",
                  "field": "question"
                },
                "value": null
              }
            }
          }
        ]
      }
      """)
      |> VegaLite.to_spec()

    assigns = Map.merge(assigns, %{spec: spec})

    ~H"""
    <div class="mt-5 py-10 px-5 overflow-x-hidden w-full flex justify-center">
      <%= OliWeb.Common.React.component(
        %{is_liveview: true},
        "Components.VegaLiteRenderer",
        %{spec: @spec},
        id: "activity_#{@activity.id}",
        container: [class: "overflow-x-scroll"],
        container_tag: :div
      ) %>
    </div>
    """
  end

  def rendered_activity(assigns) do
    ~H"""
    <RenderedActivity.render
      id={"activity_#{@activity.id}"}
      rendered_activity={@activity.preview_rendered}
    />
    """
  end

  def add_activity_attempts_info(activity, students, student_ids, section) do
    students_with_attempts =
      DeliveryResolver.students_with_attempts_for_page(
        activity,
        section,
        student_ids
      )

    student_emails_without_attempts =
      Enum.reduce(students, [], fn s, acc ->
        if s.id in students_with_attempts do
          acc
        else
          [s.email | acc]
        end
      end)

    activity
    |> Map.put(:students_with_attempts_count, Enum.count(students_with_attempts))
    |> Map.put(:student_emails_without_attempts, student_emails_without_attempts)
    |> Map.put(
      :total_attempts_count,
      count_student_attempts(activity.resource_id, section, student_ids) || 0
    )
  end

  def get_preview_rendered(nil, _activity_types_map, _section), do: nil

  def get_preview_rendered(activity_attempt, activity_types_map, section) do
    OliWeb.ManualGrading.Rendering.create_rendering_context(
      activity_attempt,
      Core.get_latest_part_attempts(activity_attempt.attempt_guid),
      activity_types_map,
      section
    )
    |> Map.merge(%{is_liveview: true})
    |> OliWeb.ManualGrading.Rendering.render(:instructor_preview)
  end

  defp add_single_response_details(activity_attempt, response_summaries) do
    responses =
      Enum.reduce(response_summaries, [], fn response_summary, acc ->
        if response_summary.activity_id == activity_attempt.resource_id do
          [
            %{
              text: response_summary.response,
              user_name: OliWeb.Common.Utils.name(response_summary.user)
            }
            | acc
          ]
        else
          acc
        end
      end)
      |> Enum.reverse()

    update_in(
      activity_attempt,
      [Access.key!(:revision), Access.key!(:content)],
      &Map.put(&1, "responses", responses)
    )
  end

  defp add_choices_frequencies(activity_attempt, response_summaries) do
    responses =
      Enum.filter(response_summaries, fn response_summary ->
        response_summary.activity_id == activity_attempt.resource_id
      end)

    # we must consider the case where a transformed model is present and if so, then use it
    # otherwise, use the revision model. This block also returns a corresponding updater function
    {model, updater} =
      case activity_attempt.transformed_model do
        nil ->
          {activity_attempt.revision.content,
           fn activity_attempt, choices ->
             update_in(
               activity_attempt,
               [Access.key!(:revision), Access.key!(:content)],
               &Map.put(&1, "choices", choices)
             )
           end}

        transformed_model ->
          {transformed_model,
           fn activity_attempt, choices ->
             update_in(
               activity_attempt,
               [Access.key!(:transformed_model)],
               &Map.put(&1, "choices", choices)
             )
           end}
      end

    choices =
      model["choices"]
      |> Enum.map(
        &Map.merge(&1, %{
          "frequency" =>
            Enum.find(responses, %{count: 0}, fn r -> r.response == &1["id"] end).count
        })
      )
      |> then(fn choices ->
        blank_reponses = Enum.find(responses, fn r -> r.response == "" end)

        if blank_reponses[:response] do
          [
            %{
              "content" => [
                %{
                  "children" => [
                    %{
                      "text" =>
                        "Blank attempt (user submitted assessment without selecting any choice for this activity)"
                    }
                  ],
                  "type" => "p"
                }
              ],
              "frequency" => blank_reponses.count
            }
            | choices
          ]
        else
          choices
        end
      end)

    updater.(activity_attempt, choices)
  end

  defp add_likert_details(activity_attempt, response_summaries) do
    {ordered_questions, question_text_mapper} =
      Enum.reduce(
        activity_attempt.revision.content["items"],
        %{ordered_questions: [], question_text_mapper: %{}},
        fn q, acc ->
          question = %{
            id: q["id"],
            text: q["content"] |> hd() |> Map.get("children") |> hd() |> Map.get("text")
          }

          %{
            ordered_questions: [question | acc.ordered_questions],
            question_text_mapper: Map.put(acc.question_text_mapper, q["id"], question.text)
          }
        end
      )
      |> then(fn acc ->
        {Enum.reverse(acc.ordered_questions), acc.question_text_mapper}
      end)

    {ordered_choices, choice_mapper} =
      Enum.reduce(
        activity_attempt.revision.content["choices"],
        %{ordered_choices: [], choice_mapper: %{}, aux_points: 1},
        fn ch, acc ->
          choice = %{
            id: ch["id"],
            text: ch["content"] |> hd() |> Map.get("children") |> hd() |> Map.get("text"),
            points: acc.aux_points
          }

          %{
            ordered_choices: [choice | acc.ordered_choices],
            choice_mapper:
              Map.put(acc.choice_mapper, ch["id"], %{text: choice.text, points: choice.points}),
            aux_points: acc.aux_points + 1
          }
        end
      )
      |> then(fn acc ->
        {Enum.reverse(acc.ordered_choices), acc.choice_mapper}
      end)

    responses =
      Enum.reduce(response_summaries, [], fn response_summary, acc ->
        if response_summary.activity_id == activity_attempt.resource_id do
          [
            %{
              count: response_summary.count,
              choice_id: response_summary.response,
              selected_choice_text:
                Map.get(choice_mapper, to_string(response_summary.response))[:text] || "",
              selected_choice_points:
                Map.get(choice_mapper, to_string(response_summary.response))[:points] || 0,
              question_id: response_summary.part_id,
              question: Map.get(question_text_mapper, to_string(response_summary.part_id))
            }
            | acc
          ]
        else
          acc
        end
      end)

    {average_points_per_question_id, responses_per_question_id} =
      Enum.reduce(responses, {%{}, %{}}, fn response, {avg_points_acc, responses_acc} ->
        {Map.put(avg_points_acc, response.question_id, [
           response.selected_choice_points | Map.get(avg_points_acc, response.question_id, [])
         ]),
         Map.put(
           responses_acc,
           response.question_id,
           Map.get(responses_acc, response.question_id, 0) + 1
         )}
      end)
      |> then(fn {points_per_question_id, responses_per_question_id} ->
        average_points_per_question_id =
          Enum.into(points_per_question_id, %{}, fn {question_id, points} ->
            count = Enum.count(points)

            {
              question_id,
              if count == 0 do
                0
              else
                Enum.sum(points) / count
              end
            }
          end)

        {average_points_per_question_id, responses_per_question_id}
      end)

    first_choice_text = Enum.at(ordered_choices, 0)[:text]
    last_choice_text = Enum.at(ordered_choices, -1)[:text]

    medians =
      Enum.map(ordered_questions, fn q ->
        %{
          question: q.text,
          median: Map.get(average_points_per_question_id, q.id, 0.0),
          lo: first_choice_text,
          hi: last_choice_text
        }
      end)

    values =
      Enum.map(responses, fn r ->
        %{
          value: r.selected_choice_points,
          choice: r.selected_choice_text,
          question: r.question,
          out_of: Map.get(responses_per_question_id, r.question_id, 0)
        }
      end)

    Map.merge(activity_attempt, %{
      datasets: %{
        medians: medians,
        values: values,
        questions_count: length(ordered_questions),
        axis_values: Enum.map(ordered_choices, fn c -> c.points end),
        first_choice_text: first_choice_text,
        last_choice_text: last_choice_text,
        title: activity_attempt.revision.title
      }
    })
  end

  defp add_multi_input_details(activity_attempt, response_summaries) do
    mapper = build_input_mapper(activity_attempt.transformed_model["inputs"])

    Enum.reduce(
      activity_attempt.transformed_model["inputs"],
      activity_attempt,
      fn input, acc2 ->
        case input["inputType"] do
          response when response in ["numeric", "text"] ->
            add_text_or_numeric_responses(
              acc2,
              response_summaries,
              mapper
            )

          "dropdown" ->
            add_dropdown_choices(acc2, response_summaries)
        end
      end
    )
  end

  defp add_dropdown_choices(acc, response_summaries) do
    add_choices_frequencies(acc, response_summaries)
    |> update_in(
      [
        Access.key!(:transformed_model),
        Access.key!("inputs"),
        Access.filter(&(&1["inputType"] == "dropdown")),
        Access.key!("choiceIds")
      ],
      &List.insert_at(&1, -1, "0")
    )
  end

  defp add_text_or_numeric_responses(acumulator, response_summaries, mapper) do
    responses =
      relevant_responses(acumulator.resource_id, response_summaries, mapper)

    update_in(
      acumulator,
      [Access.key!(:transformed_model), Access.key!("authoring")],
      &Map.put(&1, "responses", responses)
    )
  end

  defp relevant_responses(resource_id, response_summaries, mapper) do
    Enum.reduce(response_summaries, [], fn response_summary, acc_responses ->
      if response_summary.activity_id == resource_id do
        [
          %{
            text: response_summary.response,
            user_name: OliWeb.Common.Utils.name(response_summary.user),
            type: mapper[response_summary.part_id],
            part_id: response_summary.part_id
          }
          | acc_responses
        ]
      else
        acc_responses
      end
    end)
  end

  defp build_input_mapper(inputs) do
    Enum.into(inputs, %{}, fn input ->
      {input["partId"], input["inputType"]}
    end)
  end

  defp count_student_attempts(
         activity_resource_id,
         %Section{analytics_version: :v2, id: section_id},
         student_ids
       ),
       do: Summary.count_student_attempts(activity_resource_id, section_id, student_ids)

  defp count_student_attempts(
         activity_resource_id,
         section,
         student_ids
       ),
       do: Core.count_student_attempts(activity_resource_id, section.id, student_ids)
end
