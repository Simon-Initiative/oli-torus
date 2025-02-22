defmodule OliWeb.Delivery.ActivityHelpers do
  @moduledoc """
  Common helper functions for rendering activities with metrics
  in the instructor dashboard's Insights View (Scored Activities, Practice Activities and Surveys)
  """

  use OliWeb, :html

  require Logger

  alias Oli.Analytics.Summary
  alias Oli.Delivery.Sections.Section
  alias OliWeb.ManualGrading.RenderedActivity
  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Rendering.Context
  alias Oli.Activities.State.ActivityState

  @doc """
  Returns a list of summarizing details for all activities that have been attempted for a given course
  section and page. This function is used to render the Insights View in the instructor dashboard.

  We assemmble this information in the most DB efficient way possible, making only THREE
  total queries to the database. The first query gets the per-student performance summary for all
  activities on the page. The second retrieves the response summary and the final query
  resolves the revisions for each activity.

  The returned structure is:

  %{
    id: integer,
    title: string,
    revision: map,
    attempts_count: integer,
    students_with_attempts: list,
    students_with_attempts_count: integer,
    total_attempts_count: integer,
    preview_rendered: string,
    datasets: map
  }
  """
  def summarize_activity_performance(
        %Section{} = section,
        page_revision,
        activity_types_map,
        students,
        only_for_activity_ids \\ nil
      ) do

    Logger.info("Summarizing activity performance for section #{section.id} and page #{page_revision.resource_id}")

    page_id = page_revision.resource_id
    graded = page_revision.graded

    # Get the per-student performance summary for all activities on the page, then group
    # them by the activity id (which comes back as resource_id)
    student_summary =
      Summary.summarize_activities_for_page(section.id, page_id, only_for_activity_ids)

    grouped_by_activity_id = Enum.group_by(student_summary, & &1.resource_id)

    response_summaries =
      Summary.get_response_summary_for(page_id, section.id, only_for_activity_ids)

    # Then resolve the revisions for the activities
    activity_ids = Map.keys(grouped_by_activity_id)

    Logger.info("Summarizing #{Enum.count(activity_ids)} for section #{section.id} and page #{page_revision.resource_id}")

    revisions_by_resource_id =
      Oli.Publishing.DeliveryResolver.from_resource_id(section.slug, activity_ids)
      |> Enum.reduce(%{}, fn revision, acc -> Map.put(acc, revision.resource_id, revision) end)

    # NOTE: From this point forward, we make no more DB queries

    # Now total up the attempt numbers across all students for each activity
    attempt_totals =
      Enum.reduce(activity_ids, %{}, fn activity_id, acc ->
        total =
          Enum.reduce(grouped_by_activity_id[activity_id], 0, fn summary, acc ->
            acc + summary.num_attempts
          end)

        Map.put(acc, activity_id, total)
      end)

    all_emails = Enum.map(students, & &1.email) |> MapSet.new()
    ordinal_mapping = build_ordinal_mapping(page_revision)

    # Now we can assemble the final structure for each activity
    Enum.map(activity_ids, fn activity_id ->
      students_with_attempts = grouped_by_activity_id[activity_id] |> Enum.map(& &1.user_id)

      revision =
        case revisions_by_resource_id[activity_id] do
          nil -> %{title: "Unknown Activity"}
          revision -> revision
        end

      # Determine with students have not attempted this activity, all via set difference
      emails_with_attempts =
        Enum.filter(response_summaries, fn response_summary ->
          response_summary.activity_id == activity_id
        end)
        |> Enum.map(fn response_summary -> response_summary.user.email end)
        |> MapSet.new()

      student_emails_without_attempts =
        MapSet.difference(all_emails, emails_with_attempts) |> MapSet.to_list()

      %{
        id: activity_id,
        resource_id: activity_id,
        graded: graded,
        title: revision.title,
        revision: revision,
        transformed_model: nil,
        total_attempts_count: attempt_totals[activity_id],
        students_with_attempts: students_with_attempts,
        students_with_attempts_count: Enum.count(students_with_attempts),
        student_emails_without_attempts: student_emails_without_attempts
      }
    end)
    |> stage_performance_details(activity_types_map, response_summaries)
    |> Enum.map(fn activity ->
      ordinal = Map.get(ordinal_mapping, activity.resource_id)

      Map.put(
        activity,
        :preview_rendered,
        fast_preview_render(section, activity.revision, page_id, activity_types_map, ordinal)
      )
    end)
  end

  defp fast_preview_render(
         %Section{slug: section_slug},
         revision,
         page_id,
         activity_types_map,
         ordinal
       ) do
    type = Map.get(activity_types_map, revision.activity_type_id)
    state = ActivityState.create_preview_state(revision.content)

    summary = %Oli.Rendering.Activity.ActivitySummary{
      id: revision.resource_id,
      attempt_guid: "fake_attempt_guid",
      unencoded_model: revision.content,
      model: ActivityContext.prepare_model(revision.content, prune: false),
      state: ActivityContext.prepare_state(state),
      lifecycle_state: :evaluated,
      delivery_element: type.delivery_element,
      authoring_element: type.authoring_element,
      script: type.delivery_script,
      graded: false,
      bib_refs: [],
      ordinal: ordinal,
      variables: %{}
    }

    %Context{
      user: %Oli.Accounts.User{},
      section_slug: section_slug,
      revision_slug: revision.slug,
      page_id: page_id,
      mode: :review,
      activity_map: Map.put(%{}, revision.resource_id, summary),
      activity_types_map: activity_types_map,
      resource_attempt: %Oli.Delivery.Attempts.Core.ResourceAttempt{},
      is_liveview: true
    }
    |> OliWeb.ManualGrading.Rendering.render(:instructor_preview)
  end

  defp build_ordinal_mapping(revision) do
    {mapping, _} =
      revision.content
      |> Oli.Resources.PageContent.flat_filter(fn e ->
        e["type"] == "activity-reference" or e["type"] == "selection"
      end)
      |> Enum.reduce({%{}, 1}, fn e, {m, ordinal} ->
        case e["type"] do
          "activity-reference" ->
            {Map.put(m, e["activity_id"], ordinal), ordinal + 1}

          "selection" ->
            {m, ordinal + m["count"]}
        end
      end)

    mapping
  end

  def stage_performance_details(activities, activity_types_map, response_summaries) do
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

    Enum.map(activities, fn a ->
      case a.revision.activity_type_id do
        ^multiple_choice_type_id ->
          add_choices_frequencies(a, response_summaries)

        ^single_response_type_id ->
          add_single_response_details(a, response_summaries)

        ^multi_input_type_id ->
          add_multi_input_details(a, response_summaries)

        ^likert_type_id ->
          add_likert_details(a, response_summaries)

        _ ->
          a
      end
    end)
  end

  attr :activity, :map, required: true
  attr :activity_types_map, :map, required: true

  def rendered_activity(assigns) do
    case Map.get(assigns.activity_types_map, assigns.activity.revision.activity_type_id) do
      %{slug: "oli_likert"} ->
        render_likert(assigns)

      _ ->
        render_other(assigns)
    end
  end

  def render_likert(assigns) do
    spec =
      VegaLite.from_json("""
      {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "padding": {"left": 20, "top": 30, "right": 20, "bottom": 30},
        "description": "Likert Scale Ratings Distributions and Medians.",
        "datasets": {
          "medians": #{Jason.encode!(assigns.activity.datasets.medians)},
          "values": #{Jason.encode!(assigns.activity.datasets.values)}
        },
        "data": {"name": "medians"},
        "title": {"text": #{Jason.encode!(assigns.activity.datasets.title)}, "offset": 20, "fontSize": 20},
        "width": 600,
        "height": #{likert_dynamic_height(assigns.activity.datasets.questions_count)},
        "config": {
          "axis": {
            "labelColor": {"expr": "isDarkMode ? 'white' : 'black'"},
            "titleColor": {"expr": "isDarkMode ? 'white' : 'black'"},
            "gridColor": {"expr": "isDarkMode ? '#666' : '#e0e0e0'"}
          },
          "title": {"color": {"expr": "isDarkMode ? 'white' : 'black'"}},
          "legend": {
            "labelColor": {"expr": "isDarkMode ? 'red' : 'blue'"},
            "titleColor": {"expr": "isDarkMode ? 'white' : 'black'"}
          },
          "text": {"color": {"expr": "isDarkMode ? 'white' : 'black'"}}
        },
        "encoding": {
          "y": {
            "field": "question",
            "type": "nominal",
            "sort": null,
            "axis": {
              "domain": false,
              "labels": false,
              "offset": #{likert_dynamic_y_offset(assigns.activity.datasets.first_choice_text)},
              "ticks": false,
              "grid": true,
              "title": null
            }
          },
          "x": {
            "type": "quantitative",
            "scale": {"domain": #{likert_dynamic_x_scale(assigns.activity.datasets.axis_values)}},
            "axis": {"grid": false, "values": #{Jason.encode!(assigns.activity.datasets.axis_values)}, "title": null}
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
                  "offset": #{likert_dynamic_legend_offset(assigns.activity.datasets.last_choice_text)},
                  "labelColor": {"expr": "isDarkMode ? 'white' : 'black'"},
                  "type": null,
                  "symbolFillColor": {"expr": "isDarkMode ? '#4CA6FF' : '#0165DA'"},
                  "symbolStrokeColor": {"expr": "isDarkMode ? '#4CA6FF' : '#0165DA'"}
                }
              },
              "tooltip": [
                {"field": "choice", "type": "nominal", "title": "Rating"},
                {
                  "field": "value",
                  "type": "quantitative",
                  "aggregate": "count",
                  "title": "# Answers"
                },
                {"field": "out_of", "type": "nominal", "title": "Out of"}
              ],
              "color": {
                "condition": {"test": "isDarkMode", "value": "#4CA6FF"},
                "value": "#0165DA"
              }
            }
          },
          {
            "mark": "tick",
            "encoding": {
              "x": {"field": "median"},
              "color": {
                "condition": {"test": "isDarkMode", "value": "white"},
                "value": "black"
              },
              "tooltip": [
                {"field": "median", "type": "quantitative", "title": "Median"}
              ]
            }
          },
          {
            "mark": {"type": "text", "x": -10, "align": "right"},
            "encoding": {
              "text": {"field": "lo"},
              "color": {
                "condition": {"test": "isDarkMode", "value": "white"},
                "value": "black"
              }
            }
          },
          {
            "mark": {"type": "text", "x": 610, "align": "left"},
            "encoding": {
              "text": {"field": "hi"},
              "color": {
                "condition": {"test": "isDarkMode", "value": "white"},
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
              "dx": #{-likert_dynamic_y_offset(assigns.activity.datasets.first_choice_text)},
              "fontSize": 13,
              "fontWeight": "bold"
            },
            "encoding": {
              "y": {"field": "question", "type": "nominal", "sort": null},
              "x": {"value": 0},
              "text": {"field": "maybe_truncated_question"},
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

    spec =
      %{spec: spec}
      |> VegaLite.config(signals: [%{"name" => "isDarkMode", "value" => true}])

    assigns = Map.merge(assigns, spec)

    ~H"""
    <div class="mt-5 overflow-x-hidden w-full flex justify-center">
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

  defp render_other(assigns) do
    ~H"""
    <RenderedActivity.render
      id={"activity_#{@activity.id}"}
      rendered_activity={@activity.preview_rendered}
    />
    """
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
    %{questions: questions, question_mapper: question_mapper} =
      Enum.reduce(
        activity_attempt.revision.content["items"],
        %{questions: [], question_mapper: %{}, question_number: 1},
        fn q, acc ->
          question = %{
            id: q["id"],
            text: q["content"] |> hd() |> Map.get("children") |> hd() |> Map.get("text"),
            number: acc.question_number
          }

          %{
            questions: [question | acc.questions],
            question_mapper:
              Map.put(acc.question_mapper, q["id"], %{
                text: question.text,
                number: question.number
              }),
            question_number: acc.question_number + 1
          }
        end
      )

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
                Map.get(choice_mapper, to_string(response_summary.response))[:text] ||
                  "Student left this question blank",
              selected_choice_points:
                Map.get(choice_mapper, to_string(response_summary.response))[:points] || 0,
              question_id: response_summary.part_id,
              question: Map.get(question_mapper, to_string(response_summary.part_id))[:text],
              question_number:
                Map.get(question_mapper, to_string(response_summary.part_id))[:number]
            }
            | acc
          ]
        else
          acc
        end
      end)
      |> Enum.sort_by(& &1.question_number)

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
      Enum.map(questions, fn q ->
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
        questions_count: length(questions),
        axis_values: Enum.map(ordered_choices, fn c -> c.points end),
        first_choice_text: first_choice_text,
        last_choice_text: last_choice_text,
        title: activity_attempt.revision.title
      }
    })
  end

  defp add_multi_input_details(activity_attempt, response_summaries) do
    mapper = build_input_mapper(activity_attempt.revision.content["inputs"])

    Enum.reduce(
      activity_attempt.revision.content["inputs"],
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
        Access.key!(:revision),
        Access.key!(:content),
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
      [Access.key!(:revision), Access.key!(:content), Access.key!("authoring")],
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

  defp likert_dynamic_height(questions_count), do: 60 + 30 * questions_count

  defp likert_dynamic_y_offset(first_choice_text),
    do: 60 + (String.length(first_choice_text) - 7) * 5

  defp likert_dynamic_legend_offset(last_choice_text),
    do: 80 + (String.length(last_choice_text) - 7) * 5

  defp likert_dynamic_x_scale(axis_values),
    do: "[0, #{to_string(length(axis_values) + 1)}]"
end
