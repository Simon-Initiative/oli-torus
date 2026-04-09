defmodule OliWeb.Delivery.ActivityHelpers do
  @moduledoc """
  Common helper functions for rendering activities with metrics
  in the instructor dashboard's Insights View (Scored Activities, Practice Activities and Surveys)
  """

  use OliWeb, :html
  import Ecto.Query

  require Logger

  alias Oli.Analytics.Summary
  alias Oli.Analytics.Summary.ResponseLabel
  alias Oli.Activities.AdaptiveParts
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Sections.Section
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias OliWeb.ManualGrading.RenderedActivity
  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Rendering.Context
  alias Oli.Activities.State.ActivityState
  alias OliWeb.Components.Delivery.AdaptiveIFrame
  alias Phoenix.LiveView.JS

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
        only_for_activity_ids,
        opts \\ []
      ) do
    page_id = page_revision.resource_id
    graded = page_revision.graded

    # Get the per-part performance summary for all activities on the page, group them by
    # activity id, and then get the list of activity ids
    resource_summaries =
      Summary.summarize_activities_for_page(section.id, page_id, only_for_activity_ids)

    grouped_by_activity_id =
      Enum.group_by(resource_summaries, fn summary -> summary.resource_id end)

    activity_ids = Map.keys(grouped_by_activity_id)

    Logger.info(
      "Summarizing #{Enum.count(activity_ids)} for section #{section.id} and page #{page_revision.resource_id}"
    )

    # Build a map of students by their id
    students_by_id =
      Enum.reduce(students, %{}, fn student, acc -> Map.put(acc, student.id, student) end)

    # Get the response specific counts of the activities, which also includes the
    # user ids of the students who gave those responses, but along the way tracking which
    # students have attempted which activities

    # {list of all response summaries, map of activity_id -> set of user ids}
    {response_summaries, attempted_activities} =
      Summary.get_response_summary_for(page_id, section.id, only_for_activity_ids)
      |> Enum.reduce({[], %{}}, fn summary, {all, attempted_activities} ->
        # The users who have answered these responses comes over as a list of user ids,
        # so we need to convert them to a list of user structs, but careful to dedupe, handle
        # missing users, and sort them by name

        users =
          Enum.uniq(summary.users)
          |> Enum.map(fn id -> Map.get(students_by_id, id) end)
          |> Enum.filter(fn x -> x != nil end)
          |> Enum.sort_by(&{&1.family_name, &1.given_name})

        summary = %{summary | users: users}

        # Now we need to track which students have attempted which activities
        attempted_activities =
          Map.put(
            attempted_activities,
            summary.activity_id,
            MapSet.union(
              Map.get(attempted_activities, summary.activity_id, MapSet.new()),
              MapSet.new(Enum.map(users, fn user -> user.id end))
            )
          )

        {[summary | all], attempted_activities}
      end)

    revisions_by_resource_id =
      Oli.Publishing.DeliveryResolver.from_resource_id(section.slug, activity_ids)
      |> Enum.reduce(%{}, fn revision, acc -> Map.put(acc, revision.resource_id, revision) end)

    response_summaries_by_activity_part =
      group_response_summaries_by_activity_part(response_summaries)

    include_adaptive_part_analytics =
      Keyword.get(
        opts,
        :include_adaptive_part_analytics,
        Keyword.get(opts, :include_adaptive_manual_analytics, true)
      )

    adaptive_part_analytics =
      if include_adaptive_part_analytics do
        fetch_adaptive_part_analytics(
          section.id,
          revisions_by_resource_id,
          activity_types_map
        )
      else
        %{}
      end

    # NOTE: From this point forward, we make no more DB queries

    # Now total up the attempt numbers across all potential parts
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
      # Get the ids of who have attempted this activity
      emails_with_attempts =
        Map.get(attempted_activities, activity_id, MapSet.new())
        |> MapSet.to_list()
        |> Enum.map(fn id -> Map.get(students_by_id, id).email end)

      student_emails_without_attempts =
        MapSet.difference(all_emails, MapSet.new(emails_with_attempts)) |> MapSet.to_list()

      {correct, total} =
        Map.get(grouped_by_activity_id, activity_id, [])
        |> Enum.reduce({0, 0}, fn rs, {correct, total} ->
          {correct + rs.num_first_attempts_correct, total + rs.num_first_attempts}
        end)

      first_attempt_pct = if total > 0, do: correct / total, else: 0

      {correct, total} =
        Map.get(grouped_by_activity_id, activity_id, [])
        |> Enum.reduce({0, 0}, fn rs, {correct, total} ->
          {correct + rs.num_correct, total + rs.num_attempts}
        end)

      all_attempt_pct = if total > 0, do: correct / total, else: 0

      revision =
        case revisions_by_resource_id[activity_id] do
          nil -> %{title: "Unknown Activity"}
          revision -> revision
        end

      %{
        id: activity_id,
        resource_id: activity_id,
        graded: graded,
        title: revision.title,
        revision: revision,
        resource_summaries: Map.get(grouped_by_activity_id, activity_id, []),
        transformed_model: nil,
        first_attempt_pct: first_attempt_pct,
        all_attempt_pct: all_attempt_pct,
        total_attempts_count: attempt_totals[activity_id],
        students_with_attempts: emails_with_attempts,
        students_with_attempts_count: Enum.count(emails_with_attempts),
        student_emails_without_attempts: student_emails_without_attempts
      }
    end)
    |> stage_performance_details(
      activity_types_map,
      response_summaries,
      adaptive_part_analytics,
      response_summaries_by_activity_part
    )
    |> Enum.map(fn activity ->
      ordinal = Map.get(ordinal_mapping, activity.resource_id)

      student_responses = Map.get(activity, :student_responses, %{})

      Map.put(
        activity,
        :preview_rendered,
        preview_render(
          section,
          page_revision,
          activity.revision,
          activity_types_map,
          ordinal,
          student_responses
        )
      )
    end)
  end

  def preview_render(
        %Section{slug: section_slug},
        page_revision,
        revision,
        activity_types_map,
        ordinal,
        student_responses
      ) do
    type = Map.get(activity_types_map, revision.activity_type_id)

    case type.slug do
      "oli_adaptive" ->
        AdaptiveIFrame.insights_preview(section_slug, page_revision, revision)

      _ ->
        page_id = page_revision.resource_id
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

        context = %Context{
          user: %Oli.Accounts.User{},
          section_slug: section_slug,
          revision_slug: revision.slug,
          page_id: page_id,
          mode: :review,
          activity_map: Map.put(%{}, revision.resource_id, summary),
          activity_types_map: activity_types_map,
          resource_attempt: %Oli.Delivery.Attempts.Core.ResourceAttempt{},
          is_liveview: true,
          student_responses: student_responses
        }

        OliWeb.ManualGrading.Rendering.render(context, :instructor_preview)
    end
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
            {m, ordinal + e["count"]}
        end
      end)

    mapping
  end

  def stage_performance_details(
        activities,
        activity_types_map,
        response_summaries,
        adaptive_part_analytics \\ %{},
        response_summaries_by_activity_part \\ nil
      ) do
    multiple_choice_type_id =
      Enum.find_value(activity_types_map, fn {k, v} -> if v.title == "Multiple Choice", do: k end)

    cata_id =
      Enum.find_value(activity_types_map, fn {k, v} ->
        if v.title == "Check All That Apply", do: k
      end)

    single_response_type_id =
      Enum.find_value(activity_types_map, fn {k, v} -> if v.title == "Single Response", do: k end)

    multi_input_type_id =
      Enum.find_value(activity_types_map, fn {k, v} ->
        if v.title == "Multi Input",
          do: k
      end)

    likert_type_id =
      Enum.find_value(activity_types_map, fn {k, v} -> if v.title == "Likert", do: k end)

    adaptive_type_id =
      Enum.find_value(activity_types_map, fn {k, v} ->
        if Map.get(v, :slug) == "oli_adaptive", do: k
      end)

    has_adaptive_activities =
      Enum.any?(activities, fn activity ->
        activity.revision.activity_type_id == adaptive_type_id
      end)

    response_summaries_by_activity_part =
      cond do
        response_summaries_by_activity_part ->
          response_summaries_by_activity_part

        has_adaptive_activities ->
          group_response_summaries_by_activity_part(response_summaries)

        true ->
          %{}
      end

    Enum.map(activities, fn a ->
      case a.revision.activity_type_id do
        ^adaptive_type_id ->
          add_adaptive_input_details(
            a,
            response_summaries,
            adaptive_part_analytics,
            response_summaries_by_activity_part
          )

        ^multiple_choice_type_id ->
          add_choices_frequencies(a, response_summaries)

        ^cata_id ->
          add_cata_frequencies(a, response_summaries)

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
      %{slug: "oli_adaptive"} ->
        render_adaptive(assigns)

      %{slug: "oli_likert"} ->
        render_likert(assigns)

      _ ->
        render_other(assigns)
    end
  end

  attr :id, :string, required: true
  attr :value, :any, required: true
  attr :label, :string, required: true

  def percentage_bar(assigns) do
    spec = %{
      # fixed pixel width
      width: 200,
      # small bar height
      height: 30,
      layer: [
        # background gray bar
        %{
          mark: %{type: "bar", cornerRadiusEnd: 2},
          data: %{values: [%{x: 100}]},
          encoding: %{
            x: %{field: "x", type: "quantitative", axis: nil},
            # gray background
            color: %{value: "#C2C2C2"}
          }
        },
        # filled purple portion
        %{
          mark: %{type: "bar", cornerRadiusEnd: 2},
          data: %{values: [%{x: assigns.value * 100}]},
          encoding: %{
            x: %{field: "x", type: "quantitative", axis: nil},
            # dark purple
            color: %{value: "#7B19C1"}
          }
        }
      ],
      config: %{
        axis: %{domain: false, ticks: false, labels: false, title: false},
        view: %{stroke: nil},
        legend: %{disable: true},
        background: nil
      }
    }

    assigns = assign(assigns, :spec, spec)

    ~H"""
    <div class="flex justify-start font-bold">
      <div class="mt-2 mr-3">{@label}</div>
      <div>
        {OliWeb.Common.React.component(
          %{is_liveview: true},
          "Components.VegaLiteRenderer",
          %{spec: @spec},
          id: "pct-bar-#{@id}"
        )}
      </div>
      <div class="mt-2 ml-3">{format_as_int(@value)}%</div>
    </div>
    """
  end

  defp format_as_int(value) do
    round(value * 100)
  end

  defp format_percentage_1(value) when is_integer(value) do
    value
    |> Kernel.*(100)
    |> Kernel./(1)
    |> Float.round(1)
  end

  defp format_percentage_1(value) when is_float(value) do
    value
    |> Kernel.*(100)
    |> Float.round(1)
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
      |> VegaLite.config(signals: [%{"name" => "isDarkMode", "value" => true}])
      |> VegaLite.to_spec()

    assigns = Map.merge(assigns, %{spec: spec})

    ~H"""
    <div class="mt-5 overflow-x-hidden w-full flex justify-center">
      {OliWeb.Common.React.component(
        %{is_liveview: true},
        "Components.VegaLiteRenderer",
        %{spec: @spec},
        id: "activity_#{@activity.id}",
        container: [class: "overflow-x-scroll"],
        container_tag: :div
      )}
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

  defp render_adaptive(assigns) do
    activity_row_id = Map.get(assigns.activity, :resource_id, assigns.activity.id)
    responses_tab_id = "adaptive-responses-tab-#{assigns.activity.id}"
    responses_panel_id = "adaptive-responses-panel-#{assigns.activity.id}"
    preview_tab_id = "adaptive-preview-tab-#{assigns.activity.id}"
    preview_panel_id = "adaptive-preview-panel-#{assigns.activity.id}"
    preview_template_id = "adaptive-preview-template-#{assigns.activity.id}"

    assigns =
      assign(assigns,
        preview_tab_id: preview_tab_id,
        responses_tab_id: responses_tab_id,
        preview_panel_id: preview_panel_id,
        responses_panel_id: responses_panel_id,
        preview_template_id: preview_template_id,
        activity_row_id: activity_row_id,
        input_summaries: Map.get(assigns.activity, :adaptive_input_summaries, [])
      )

    ~H"""
    <div class="pt-6">
      <div class="flex gap-6 border-b border-gray-300 dark:border-gray-700">
        <button
          id={@responses_tab_id}
          type="button"
          class="border-b-2 border-blue-500 px-1 py-3 text-sm font-semibold uppercase tracking-wide text-blue-600 dark:text-blue-400"
          phx-hook="PreserveScrollAnchor"
          data-anchor-selector={~s(tr[data-row-id="row_#{@activity_row_id}"])}
          phx-click={
            adaptive_tab_js(
              @responses_tab_id,
              @preview_tab_id,
              @responses_panel_id,
              @preview_panel_id
            )
          }
        >
          Student Responses
        </button>
        <button
          id={@preview_tab_id}
          type="button"
          class="border-b-2 border-transparent px-1 py-3 text-sm font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400"
          phx-hook="PreserveScrollAnchor"
          data-anchor-selector={~s(tr[data-row-id="row_#{@activity_row_id}"])}
          phx-click={
            adaptive_tab_js(
              @preview_tab_id,
              @responses_tab_id,
              @preview_panel_id,
              @responses_panel_id
            )
          }
        >
          Screen Preview
        </button>
      </div>

      <div id={@responses_panel_id} class="pt-6">
        <%= if Enum.empty?(@input_summaries) do %>
          <p class="text-sm text-gray-600 dark:text-gray-300">
            No student response summary is available for this screen.
          </p>
        <% else %>
          <div class="grid gap-4">
            <%= for summary <- @input_summaries do %>
              <.adaptive_input_summary activity={@activity} summary={summary} />
            <% end %>
          </div>
        <% end %>
      </div>

      <div
        id={@preview_panel_id}
        class="hidden pt-6"
        phx-hook="AdaptivePreviewPanel"
        data-preview-template-id={@preview_template_id}
      >
      </div>
      <template id={@preview_template_id}>
        <RenderedActivity.render
          id={"activity_#{@activity.id}"}
          rendered_activity={@activity.preview_rendered}
        />
      </template>
    </div>
    """
  end

  attr :activity, :map, required: true
  attr :summary, :map, required: true

  defp adaptive_input_summary(assigns) do
    assigns =
      assign(assigns,
        visualization: Map.get(assigns.summary, :visualization, %{}),
        outcome_buckets: Map.get(assigns.summary, :outcome_buckets, [])
      )

    ~H"""
    <div class="rounded-xl border border-gray-200 bg-gray-50 px-5 py-5 shadow-sm dark:border-gray-700 dark:bg-gray-900/30">
      <div class="flex items-start justify-between gap-4 border-b border-gray-200 pb-4 dark:border-gray-700">
        <div>
          <div class="font-semibold text-gray-900 dark:text-white">{@summary.label}</div>
          <div class="mt-2 flex flex-wrap items-center gap-2">
            <div class="text-xs uppercase tracking-wide text-gray-500 dark:text-gray-400">
              {@summary.component_type}
            </div>
            <div class={[
              "inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-semibold uppercase tracking-wide",
              adaptive_grading_badge_classes(@summary.grading_mode)
            ]}>
              {@summary.grading_mode_label}
            </div>
          </div>
        </div>
        <div class="text-xs text-gray-500 dark:text-gray-400">{@summary.part_id}</div>
      </div>

      <div class="mt-4">
        <.render_adaptive_visualization summary={@summary} visualization={@visualization} />
      </div>

      <div
        :if={@summary.grading_pending}
        class="mt-5 rounded-xl bg-amber-50 px-4 py-4 text-sm text-amber-900 dark:bg-amber-500/10 dark:text-amber-100"
      >
        {@summary.grading_pending_message}
      </div>
    </div>
    """
  end

  attr :summary, :map, required: true
  attr :visualization, :map, required: true

  defp render_adaptive_visualization(
         %{visualization: %{kind: :choice_distribution} = visualization} = assigns
       ) do
    assigns = assign(assigns, visualization: visualization)

    ~H"""
    <div class="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(0,1.2fr)_minmax(16rem,0.8fr)]">
      <div class="rounded-xl bg-white px-4 py-4 dark:bg-gray-800/70">
        <div class="text-sm font-semibold text-gray-900 dark:text-white">
          {@visualization.prompt}
        </div>
        <div :if={@visualization.description} class="mt-1 text-sm text-gray-500 dark:text-gray-400">
          {@visualization.description}
        </div>

        <div class="mt-4 space-y-3">
          <%= for choice <- @visualization.choices do %>
            <div class="rounded-lg border border-gray-200 bg-gray-50 px-4 py-3 dark:border-gray-700 dark:bg-gray-900/50">
              <div class="flex items-center justify-between gap-4 text-sm">
                <div class="flex items-center gap-3">
                  <div class={[
                    "h-3 w-3 rounded-full border",
                    adaptive_choice_marker_classes(choice, @summary.grading_mode)
                  ]}>
                  </div>
                  <div class="flex flex-wrap items-center gap-2">
                    <div class="font-medium text-gray-900 dark:text-white">{choice.label}</div>
                    <.badge_with_tooltip
                      :if={Map.get(choice, :native_correct) == true}
                      class={native_key_badge_classes()}
                      tooltip="This badge marks the authored answer key for the input. It indicates the native correct option defined in the content model."
                    >
                      Answer Key
                    </.badge_with_tooltip>
                    <.badge_with_tooltip
                      :if={@summary.grading_mode == :manual and manual_outcome_badge_label(choice)}
                      class={manual_outcome_badge_classes(Map.get(choice, :correctness))}
                      tooltip={manual_outcome_badge_tooltip(Map.get(choice, :correctness))}
                    >
                      {manual_outcome_badge_label(choice)}
                    </.badge_with_tooltip>
                  </div>
                </div>
                <div class="text-right text-xs text-gray-500 dark:text-gray-400">
                  <div>
                    {choice.count} of {@visualization.denominator_count} {@visualization.denominator_label}
                  </div>
                  <div>{format_percentage_1(choice.ratio)}%</div>
                </div>
              </div>
              <div class="mt-3 h-3 overflow-hidden rounded-full bg-gray-200 dark:bg-gray-950">
                <div
                  class={[
                    "h-3 rounded-full transition-all",
                    adaptive_choice_fill_classes(choice, @summary.grading_mode)
                  ]}
                  style={"width: #{format_percentage_1(choice.ratio)}%; min-width: #{if choice.count > 0, do: "0.5rem", else: "0"};"}
                >
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <div class="rounded-xl bg-white px-4 py-4 dark:bg-gray-800/70">
        <div class="text-sm font-semibold text-gray-900 dark:text-white">Distribution Notes</div>
        <div class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
          {@visualization.summary}
        </div>
        <div
          :if={Map.get(@visualization, :multi_select)}
          class="mt-3 rounded-lg bg-sky-50 px-3 py-3 text-sm leading-6 text-sky-900 dark:bg-sky-500/10 dark:text-sky-100"
        >
          <div class="text-xs font-semibold uppercase tracking-wide">Input Type</div>
          <div class="mt-1 font-semibold">{@visualization.selection_mode_label}</div>
          <div class="mt-2">
            {@visualization.combination_summary}
          </div>
          <div :if={Map.get(@visualization, :authored_correct_combination)} class="mt-2 text-xs">
            Authored correct combination:
            <span class="font-semibold">{@visualization.authored_correct_combination}</span>
          </div>
        </div>
        <div class="mt-2 text-xs text-gray-500 dark:text-gray-400">
          Bar width represents the share of {@visualization.denominator_label} for this input.
        </div>
        <div
          :if={
            Map.get(@visualization, :multi_select) == true and
              Map.get(@visualization, :combination_entries, []) != []
          }
          class="mt-4 rounded-lg bg-gray-100 px-3 py-3 dark:bg-gray-900/60"
        >
          <div class="text-sm font-semibold text-gray-900 dark:text-white">
            Most Common Answer Combinations
          </div>
          <div class="mt-3 space-y-3">
            <%= for entry <- Map.get(@visualization, :combination_entries, []) do %>
              <div>
                <div class="flex items-start justify-between gap-3 text-sm">
                  <div class="min-w-0">
                    <div class="flex flex-wrap items-center gap-2">
                      <div class="font-medium text-gray-900 dark:text-white">{entry.label}</div>
                      <span
                        :if={entry.correct == true}
                        class="inline-flex items-center rounded-full bg-emerald-100 px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide text-emerald-800 dark:bg-emerald-500/20 dark:text-emerald-200"
                      >
                        Correct Combination
                      </span>
                    </div>
                  </div>
                  <div class="text-right text-xs text-gray-500 dark:text-gray-400">
                    <div>
                      {entry.count} of {Map.get(@visualization, :combination_denominator_count, 0)} responses
                    </div>
                    <div>{format_percentage_1(entry.ratio)}%</div>
                  </div>
                </div>
                <div class="mt-2 h-2 overflow-hidden rounded-full bg-gray-200 dark:bg-gray-950">
                  <div
                    class={[
                      "h-2 rounded-full transition-all",
                      if(entry.correct == true,
                        do: "bg-emerald-500 dark:bg-emerald-400",
                        else: "bg-sky-500 dark:bg-sky-400"
                      )
                    ]}
                    style={"width: #{format_percentage_1(entry.ratio)}%; min-width: #{if entry.count > 0, do: "0.4rem", else: "0"};"}
                  >
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        <.render_adaptive_coverage summary={@summary} />
        <.render_adaptive_outcome_breakdown summary={@summary} />
        <div
          :if={Map.get(@visualization, :native_key_note)}
          class="mt-3 rounded-lg bg-emerald-50 px-3 py-2 text-xs font-medium text-emerald-800 dark:bg-emerald-500/10 dark:text-emerald-200"
        >
          {@visualization.native_key_note}
        </div>
      </div>
    </div>
    """
  end

  defp render_adaptive_visualization(
         %{visualization: %{kind: :response_patterns} = visualization} = assigns
       ) do
    assigns = assign(assigns, visualization: visualization)

    ~H"""
    <div class="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(0,1.2fr)_minmax(16rem,0.8fr)]">
      <div class="rounded-xl bg-white px-4 py-4 dark:bg-gray-800/70">
        <div class="text-sm font-semibold text-gray-900 dark:text-white">
          {@visualization.prompt}
        </div>
        <div :if={@visualization.description} class="mt-1 text-sm text-gray-500 dark:text-gray-400">
          {@visualization.description}
        </div>

        <div :if={@visualization.entries == []} class="mt-4 text-sm text-gray-600 dark:text-gray-300">
          No submitted response patterns are available for this input yet.
        </div>

        <div
          :if={@visualization.entries != []}
          class="mt-4 max-h-[34rem] space-y-3 overflow-y-auto pr-1"
        >
          <%= for entry <- @visualization.entries do %>
            <div class="rounded-lg border border-gray-200 bg-gray-50 px-4 py-3 dark:border-gray-700 dark:bg-gray-900/50">
              <div class="flex items-start justify-between gap-4 text-sm">
                <div class="min-w-0 flex-1">
                  <div class="font-medium text-gray-900 dark:text-white">{entry.label}</div>
                  <div
                    :if={Map.get(entry, :supporting_text)}
                    class="mt-1 text-xs text-gray-500 dark:text-gray-400"
                  >
                    {entry.supporting_text}
                  </div>
                </div>
                <div class="text-right text-xs text-gray-500 dark:text-gray-400">
                  <div>{entry.count} of {@visualization.denominator_count} responses</div>
                  <div>{format_percentage_1(entry.ratio)}%</div>
                </div>
              </div>
              <div class="mt-3 h-3 overflow-hidden rounded-full bg-gray-200 dark:bg-gray-950">
                <div
                  class={[
                    "h-3 rounded-full transition-all",
                    Map.get(@visualization, :fill_class, "bg-sky-500 dark:bg-sky-400")
                  ]}
                  style={"width: #{format_percentage_1(entry.ratio)}%; min-width: #{if entry.count > 0, do: "0.5rem", else: "0"};"}
                >
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <div class="rounded-xl bg-white px-4 py-4 dark:bg-gray-800/70">
        <div class="text-sm font-semibold text-gray-900 dark:text-white">Distribution Notes</div>
        <div class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
          {@visualization.summary}
        </div>
        <div
          :if={Map.get(@visualization, :explanation)}
          class="mt-3 rounded-lg bg-gray-100 px-3 py-3 text-sm leading-6 text-gray-600 dark:bg-gray-900/60 dark:text-gray-300"
        >
          {@visualization.explanation}
        </div>
        <div class="mt-3 rounded-lg bg-sky-50 px-3 py-3 text-sm leading-6 text-sky-900 dark:bg-sky-500/10 dark:text-sky-100">
          <div class="font-medium">
            Showing all {Map.get(
              @visualization,
              :unique_pattern_count,
              length(@visualization.entries)
            )} unique submission patterns.
          </div>
        </div>
        <div class="mt-2 text-xs text-gray-500 dark:text-gray-400">
          Bar width represents the share of responses recorded for this input.
        </div>
        <.render_adaptive_coverage summary={@summary} />
        <.render_adaptive_outcome_breakdown summary={@summary} />
      </div>
    </div>
    """
  end

  defp render_adaptive_visualization(
         %{visualization: %{kind: :numeric_distribution} = visualization} = assigns
       ) do
    assigns = assign(assigns, visualization: visualization)

    ~H"""
    <div class="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(0,1.2fr)_minmax(16rem,0.8fr)]">
      <div class="rounded-xl bg-white px-4 py-4 dark:bg-gray-800/70">
        <div class="text-sm font-semibold text-gray-900 dark:text-white">
          {@visualization.prompt}
        </div>
        <div :if={@visualization.description} class="mt-1 text-sm text-gray-500 dark:text-gray-400">
          {@visualization.description}
        </div>

        <div :if={@visualization.entries == []} class="mt-4 text-sm text-gray-600 dark:text-gray-300">
          No ordered numeric responses are available for this input yet.
        </div>

        <div
          :if={@visualization.entries != [] and Map.get(@visualization, :scale_kind) == :text_slider}
          class="mt-4 rounded-xl border border-gray-200 bg-gray-50 px-4 py-4 dark:border-gray-700 dark:bg-gray-900/50"
        >
          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <%= for entry <- @visualization.entries do %>
              <div class="rounded-lg border border-gray-200 bg-white px-4 py-3 dark:border-gray-700 dark:bg-gray-900/80">
                <div class="flex items-start justify-between gap-3">
                  <div class="min-w-0">
                    <div class="flex items-center gap-2">
                      <span class="inline-flex h-6 min-w-6 items-center justify-center rounded-full bg-gray-100 px-2 text-[11px] font-semibold uppercase tracking-wide text-gray-600 dark:bg-gray-800 dark:text-gray-300">
                        {entry.step_label}
                      </span>
                      <div class="truncate text-sm font-semibold text-gray-900 dark:text-white">
                        {entry.label}
                      </div>
                    </div>
                  </div>
                  <div class="text-right text-xs text-gray-500 dark:text-gray-400">
                    <div>{entry.count} selections</div>
                    <div>{format_percentage_1(entry.ratio)}%</div>
                  </div>
                </div>
                <div class="mt-3 h-2 overflow-hidden rounded-full bg-gray-200 dark:bg-gray-950">
                  <div
                    class={[
                      "h-2 rounded-full transition-all",
                      Map.get(@visualization, :fill_class, "bg-cyan-500 dark:bg-cyan-400")
                    ]}
                    style={"width: #{format_percentage_1(entry.ratio)}%; min-width: #{if entry.count > 0, do: "0.4rem", else: "0"};"}
                  >
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div
          :if={@visualization.entries != [] and Map.get(@visualization, :scale_kind) != :text_slider}
          class="mt-4 space-y-3"
        >
          <%= for entry <- @visualization.entries do %>
            <div class="rounded-lg border border-gray-200 bg-gray-50 px-4 py-3 dark:border-gray-700 dark:bg-gray-900/50">
              <div class="flex items-center justify-between gap-4 text-sm">
                <div class="flex min-w-0 items-center gap-3">
                  <span
                    :if={Map.get(entry, :step_label)}
                    class="inline-flex h-6 min-w-6 items-center justify-center rounded-full bg-gray-100 px-2 text-[11px] font-semibold uppercase tracking-wide text-gray-600 dark:bg-gray-800 dark:text-gray-300"
                  >
                    {entry.step_label}
                  </span>
                  <div class="font-medium text-gray-900 dark:text-white">{entry.label}</div>
                </div>
                <div class="text-right text-xs text-gray-500 dark:text-gray-400">
                  <div>{entry.count} of {@visualization.denominator_count} responses</div>
                  <div>{format_percentage_1(entry.ratio)}%</div>
                </div>
              </div>
              <div class="mt-3 h-3 overflow-hidden rounded-full bg-gray-200 dark:bg-gray-950">
                <div
                  class={[
                    "h-3 rounded-full transition-all",
                    Map.get(@visualization, :fill_class, "bg-cyan-500 dark:bg-cyan-400")
                  ]}
                  style={"width: #{format_percentage_1(entry.ratio)}%; min-width: #{if entry.count > 0, do: "0.5rem", else: "0"};"}
                >
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <div class="rounded-xl bg-white px-4 py-4 dark:bg-gray-800/70">
        <div class="text-sm font-semibold text-gray-900 dark:text-white">Distribution Notes</div>
        <div class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
          {@visualization.summary}
        </div>
        <div
          :if={Map.get(@visualization, :scale_hint)}
          class="mt-3 rounded-lg bg-gray-100 px-3 py-3 dark:bg-gray-900/60"
        >
          <div class="text-xs font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400">
            Scale Range
          </div>
          <div class="mt-2 flex items-center justify-between gap-3 text-sm font-medium text-gray-900 dark:text-white">
            <span class="truncate">{@visualization.scale_hint.min_label}</span>
            <span class="text-xs uppercase tracking-wide text-gray-500 dark:text-gray-400">to</span>
            <span class="truncate text-right">{@visualization.scale_hint.max_label}</span>
          </div>
        </div>
        <div class="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div
            :for={stat <- @visualization.stats}
            class="rounded-lg bg-gray-100 px-3 py-3 dark:bg-gray-900/60"
          >
            <div class="text-xs font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400">
              {stat.label}
            </div>
            <div class="mt-2 text-lg font-semibold text-gray-900 dark:text-white">{stat.value}</div>
            <div
              :if={Map.get(stat, :supporting_text)}
              class="mt-1 text-xs text-gray-500 dark:text-gray-400"
            >
              {stat.supporting_text}
            </div>
          </div>
        </div>
        <.render_adaptive_coverage summary={@summary} />
        <.render_adaptive_outcome_breakdown summary={@summary} />
      </div>
    </div>
    """
  end

  defp render_adaptive_visualization(
         %{visualization: %{kind: :correctness_distribution} = visualization} = assigns
       ) do
    assigns = assign(assigns, visualization: visualization)

    ~H"""
    <div class="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(16rem,0.8fr)_minmax(0,1.2fr)]">
      <div class="rounded-xl bg-white px-4 py-4 dark:bg-gray-800/70">
        <div class="text-sm font-semibold text-gray-900 dark:text-white">
          {@visualization.prompt}
        </div>
        <div :if={@visualization.description} class="mt-1 text-sm text-gray-500 dark:text-gray-400">
          {@visualization.description}
        </div>
      </div>

      <div class="rounded-xl bg-white px-4 py-4 dark:bg-gray-800/70">
        <div class="text-sm text-gray-600 dark:text-gray-300">
          {@visualization.summary}
        </div>
        <.render_adaptive_coverage summary={@summary} />
        <.render_adaptive_outcome_breakdown summary={@summary} />
      </div>
    </div>
    """
  end

  defp render_adaptive_visualization(_assigns) do
    assigns = %{}

    ~H"""
    <div class="rounded-xl bg-white px-4 py-4 text-sm text-gray-600 dark:bg-gray-800/70 dark:text-gray-300">
      No aggregate response details are available for this input.
    </div>
    """
  end

  attr :summary, :map, required: true

  defp render_adaptive_coverage(assigns) do
    ~H"""
    <div class="mt-4 rounded-lg bg-gray-100 px-3 py-3 dark:bg-gray-900/60">
      <div class="text-sm font-semibold text-gray-900 dark:text-white">
        {if @summary.grading_mode == :manual, do: "Graded Coverage", else: "Response Coverage"}
      </div>
      <div class="mt-3 text-xs font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400">
        {Map.get(@summary, :coverage_student_label, "Students")}
      </div>
      <div class="mt-2 text-lg font-semibold text-gray-900 dark:text-white">
        {Map.get(@summary, :coverage_student_count, @summary.student_count)}
      </div>
    </div>
    """
  end

  attr :summary, :map, required: true

  defp render_adaptive_outcome_breakdown(%{summary: %{grading_pending: true}} = assigns) do
    ~H""
  end

  defp render_adaptive_outcome_breakdown(assigns) do
    outcome_buckets = Map.get(assigns.summary, :outcome_buckets, [])

    outcome_total_count =
      Map.get(assigns.summary, :outcome_total_count, assigns.summary.attempt_count)

    outcome_total_label = Map.get(assigns.summary, :outcome_total_label, "attempts")

    assigns = assign(assigns, outcome_buckets: outcome_buckets)
    assigns = assign(assigns, outcome_total_count: outcome_total_count)
    assigns = assign(assigns, outcome_total_label: outcome_total_label)

    ~H"""
    <div class="mt-4 rounded-lg bg-gray-100 px-3 py-3 dark:bg-gray-900/60">
      <div class="text-sm font-semibold text-gray-900 dark:text-white">
        Outcome Breakdown
      </div>
      <div class="mt-4 space-y-3">
        <%= for bucket <- @outcome_buckets do %>
          <div>
            <div class="flex items-center justify-between gap-3 text-sm">
              <div class="font-medium text-gray-900 dark:text-white">{bucket.label}</div>
              <div class="text-xs text-gray-500 dark:text-gray-400">
                {bucket.count} of {@outcome_total_count} {@outcome_total_label} ({format_percentage_1(
                  bucket.ratio
                )}%)
              </div>
            </div>
            <div class="mt-2 h-3 overflow-hidden rounded-full bg-gray-200 dark:bg-gray-900">
              <div
                class={["h-3 rounded-full transition-all", bucket.fill_class]}
                style={"width: #{format_percentage_1(bucket.ratio)}%; min-width: #{if bucket.count > 0, do: "0.5rem", else: "0"};"}
              >
              </div>
            </div>
          </div>
        <% end %>
      </div>
      <div class="mt-5 flex flex-wrap gap-x-10 gap-y-4">
        <.percentage_bar
          id={"adaptive_#{@summary.part_id}_first_try_correct"}
          value={@summary.first_attempt_pct}
          label="First Try Correct"
        />
        <.percentage_bar
          id={"adaptive_#{@summary.part_id}_eventually_correct"}
          value={@summary.all_attempt_pct}
          label="Eventually Correct"
        />
      </div>
    </div>
    """
  end

  defp adaptive_choice_marker_classes(choice, grading_mode) when is_map(choice) do
    choice
    |> adaptive_choice_visual_state(grading_mode)
    |> adaptive_choice_marker_classes()
  end

  defp adaptive_choice_marker_classes(:native_and_awarded_full),
    do:
      "border-emerald-500 bg-sky-500 ring-2 ring-emerald-300 dark:border-emerald-400 dark:bg-sky-400 dark:ring-emerald-500/40"

  defp adaptive_choice_marker_classes(:awarded_full),
    do: "border-sky-500 bg-sky-500 dark:border-sky-400 dark:bg-sky-400"

  defp adaptive_choice_marker_classes(:native_correct),
    do: "border-emerald-500 bg-emerald-500 dark:border-emerald-400 dark:bg-emerald-400"

  defp adaptive_choice_marker_classes(true),
    do: "border-emerald-500 bg-emerald-500 dark:border-emerald-400 dark:bg-emerald-400"

  defp adaptive_choice_marker_classes(false),
    do: "border-red-500 bg-red-500 dark:border-red-400 dark:bg-red-400"

  defp adaptive_choice_marker_classes(:partial),
    do: "border-amber-500 bg-amber-500 dark:border-amber-400 dark:bg-amber-400"

  defp adaptive_choice_marker_classes(_),
    do: "border-slate-400 bg-slate-400 dark:border-slate-500 dark:bg-slate-500"

  defp adaptive_choice_fill_classes(choice, grading_mode) when is_map(choice) do
    choice
    |> adaptive_choice_visual_state(grading_mode)
    |> adaptive_choice_fill_classes()
  end

  defp adaptive_choice_fill_classes(:native_and_awarded_full),
    do: "bg-gradient-to-r from-emerald-500 to-sky-500 dark:from-emerald-400 dark:to-sky-400"

  defp adaptive_choice_fill_classes(:awarded_full), do: "bg-sky-500 dark:bg-sky-400"
  defp adaptive_choice_fill_classes(:native_correct), do: "bg-emerald-500 dark:bg-emerald-400"
  defp adaptive_choice_fill_classes(true), do: "bg-emerald-500 dark:bg-emerald-400"
  defp adaptive_choice_fill_classes(false), do: "bg-red-500 dark:bg-red-400"
  defp adaptive_choice_fill_classes(:partial), do: "bg-amber-500 dark:bg-amber-400"
  defp adaptive_choice_fill_classes(_), do: "bg-slate-400 dark:bg-slate-500"

  defp adaptive_choice_visual_state(choice, :manual) do
    native_correct? = Map.get(choice, :native_correct) == true

    case {native_correct?, Map.get(choice, :correctness)} do
      {true, true} -> :native_and_awarded_full
      {true, _} -> :native_correct
      {false, true} -> :awarded_full
      {false, false} -> false
      {false, :partial} -> :partial
      {false, other} -> other
    end
  end

  defp adaptive_choice_visual_state(choice, _grading_mode) do
    if Map.get(choice, :native_correct) == true do
      :native_correct
    else
      Map.get(choice, :correctness, Map.get(choice, :correct))
    end
  end

  defp adaptive_visualization_fill_class(%{grading_pending: true}),
    do: "bg-slate-400 dark:bg-slate-500"

  defp adaptive_visualization_fill_class(%{attempt_total_count: 0}),
    do: "bg-slate-400 dark:bg-slate-500"

  defp adaptive_visualization_fill_class(%{evaluation_confidence: :inferred}),
    do: "bg-sky-500 dark:bg-sky-400"

  defp adaptive_visualization_fill_class(%{all_attempt_pct: pct}) when pct >= 1.0,
    do: "bg-emerald-500 dark:bg-emerald-400"

  defp adaptive_visualization_fill_class(%{all_attempt_pct: pct}) when pct <= 0.0,
    do: "bg-amber-500 dark:bg-amber-400"

  defp adaptive_visualization_fill_class(_),
    do: "bg-violet-500 dark:bg-violet-400"

  defp native_key_badge_classes do
    "inline-flex items-center rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-emerald-800 dark:bg-emerald-500/20 dark:text-emerald-200"
  end

  defp manual_outcome_badge_label(%{correctness: true}), do: "Awarded Full Credit"
  defp manual_outcome_badge_label(%{correctness: false}), do: "Awarded No Credit"
  defp manual_outcome_badge_label(%{correctness: :partial}), do: "Awarded Partial Credit"
  defp manual_outcome_badge_label(_), do: nil

  defp manual_outcome_badge_classes(true),
    do:
      "inline-flex items-center rounded-full bg-sky-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-sky-800 dark:bg-sky-500/20 dark:text-sky-200"

  defp manual_outcome_badge_classes(false),
    do:
      "inline-flex items-center rounded-full bg-rose-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-rose-800 dark:bg-rose-500/20 dark:text-rose-200"

  defp manual_outcome_badge_classes(:partial),
    do:
      "inline-flex items-center rounded-full bg-orange-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-orange-800 dark:bg-orange-500/20 dark:text-orange-200"

  defp manual_outcome_badge_classes(_),
    do:
      "inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-slate-800 dark:bg-slate-500/20 dark:text-slate-200"

  defp manual_outcome_badge_tooltip(true),
    do:
      "Instructor grading awarded full credit for submissions associated with this option, regardless of whether it matches the native answer key."

  defp manual_outcome_badge_tooltip(false),
    do: "Instructor grading awarded no credit for submissions associated with this option."

  defp manual_outcome_badge_tooltip(:partial),
    do: "Instructor grading awarded partial credit for submissions associated with this option."

  defp manual_outcome_badge_tooltip(_), do: nil

  attr :class, :string, required: true
  attr :tooltip, :string, required: true
  slot :inner_block, required: true

  defp badge_with_tooltip(assigns) do
    ~H"""
    <span class="group relative inline-flex">
      <span
        tabindex="0"
        class={[@class, "cursor-help outline-none"]}
        aria-label={@tooltip}
      >
        {render_slot(@inner_block)}
      </span>
      <span class="pointer-events-none absolute bottom-full left-1/2 z-20 mb-2 hidden w-64 -translate-x-1/2 rounded-lg border border-Border-border-default bg-Surface-surface-background px-3 py-2 text-left text-xs font-normal normal-case tracking-normal text-Text-text-high shadow-[0px_12px_24px_0px_rgba(53,55,64,0.12)] group-hover:block group-focus-within:block">
        {@tooltip}
      </span>
    </span>
    """
  end

  defp adaptive_tab_js(active_tab_id, inactive_tab_id, active_panel_id, inactive_panel_id) do
    JS.remove_class("hidden", to: "##{active_panel_id}")
    |> JS.add_class("hidden", to: "##{inactive_panel_id}")
    |> JS.remove_class("border-transparent text-gray-500 dark:text-gray-400",
      to: "##{active_tab_id}"
    )
    |> JS.add_class(
      "border-b-2 border-blue-500 text-blue-600 dark:text-blue-400",
      to: "##{active_tab_id}"
    )
    |> JS.remove_class(
      "border-b-2 border-blue-500 text-blue-600 dark:text-blue-400",
      to: "##{inactive_tab_id}"
    )
    |> JS.add_class("border-transparent text-gray-500 dark:text-gray-400",
      to: "##{inactive_tab_id}"
    )
  end

  defp add_single_response_details(activity_attempt, response_summaries) do
    responses =
      Enum.filter(response_summaries, fn rs -> rs.activity_id == activity_attempt.resource_id end)
      |> Enum.map(fn rs ->
        %{
          text: rs.response,
          users: Enum.map(rs.users, fn user -> OliWeb.Common.Utils.name(user) end)
        }
      end)

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

    model =
      case activity_attempt.transformed_model do
        nil ->
          activity_attempt.revision.content

        transformed_model ->
          transformed_model
      end

    first_part = model["authoring"]["parts"] |> Enum.at(0)
    part_id = first_part["id"]

    # index of 0 = A, 1 = B, etc.
    to_letter = fn index ->
      <<index + 65>> <> "."
    end

    correct_response =
      Enum.reduce(first_part["responses"], first_part["responses"] |> hd, fn r, acc ->
        case r["score"] > acc["score"] do
          true -> r
          false -> acc
        end
      end)

    # From this rule format, determine the set of correct choice IDs
    # "(!(input like {617912613})) && (input like {1708872710} && (input like {2311585959}))"
    correct_choice_ids =
      Enum.map(model["choices"], fn choice -> choice["id"] end)
      |> Enum.filter(fn choice_id ->
        String.contains?(correct_response["rule"], "{" <> choice_id <> "}")
      end)
      |> MapSet.new()

    values =
      model["choices"]
      |> Enum.with_index()
      |> Enum.map(fn {c, index} ->
        %{
          "label" => to_letter.(index),
          "count" => Enum.find(responses, %{count: 0}, fn r -> r.response == c["id"] end).count,
          "correct" => MapSet.member?(correct_choice_ids, c["id"]),
          "part_id" => part_id
        }
      end)

    grouped = Enum.group_by(values, fn r -> r["part_id"] end)

    sr = Map.get(activity_attempt, :student_responses, %{})
    Map.put(activity_attempt, :student_responses, Map.merge(sr, grouped))
  end

  defp add_cata_frequencies(activity_attempt, response_summaries) do
    responses =
      Enum.filter(response_summaries, fn response_summary ->
        response_summary.activity_id == activity_attempt.resource_id
      end)

    # we must consider the case where a transformed model is present and if so, then use it
    # otherwise, use the revision model. This block also returns a corresponding updater function
    model =
      case activity_attempt.transformed_model do
        nil ->
          activity_attempt.revision.content

        transformed_model ->
          transformed_model
      end

    first_part = model["authoring"]["parts"] |> Enum.at(0)
    part_id = first_part["id"]

    correct_response =
      Enum.reduce(first_part["responses"], first_part["responses"] |> hd, fn r, acc ->
        case r["score"] > acc["score"] do
          true -> r
          false -> acc
        end
      end)

    # From this rule format, determine the set of correct choice IDs
    # "(!(input like {617912613})) && (input like {1708872710} && (input like {2311585959}))"
    correct_choice_ids =
      Enum.map(model["choices"], fn choice -> choice["id"] end)
      |> Enum.filter(fn choice_id ->
        pattern = ~r/!\s*\([^)]*input\s+like\s+\{#{Regex.escape(choice_id)}\}/
        negated = Regex.match?(pattern, correct_response["rule"])

        present_pattern = ~r/input\s+like\s+\{#{Regex.escape(choice_id)}\}/
        present = Regex.match?(present_pattern, correct_response["rule"])

        present and not negated
      end)
      |> MapSet.new()

    # index of 0 = A, 1 = B, etc.
    to_letter = fn index ->
      <<index + 65>> <> "."
    end

    values =
      model["choices"]
      |> Enum.with_index()
      |> Enum.map(fn {c, index} ->
        count =
          Enum.reduce(responses, 0, fn r, acc ->
            choice_ids = String.split(r.response, " ", trim: true)

            if Enum.member?(choice_ids, c["id"]) do
              acc + r.count
            else
              acc
            end
          end)

        %{
          "label" => to_letter.(index),
          "count" => count,
          "correct" => MapSet.member?(correct_choice_ids, c["id"]),
          "part_id" => part_id
        }
      end)

    grouped = Enum.group_by(values, fn r -> r["part_id"] end)

    sr = Map.get(activity_attempt, :student_responses, %{})
    Map.put(activity_attempt, :student_responses, Map.merge(sr, grouped))
  end

  defp add_likert_details(activity, response_summaries) do
    %{questions: questions, question_mapper: question_mapper} =
      Enum.reduce(
        activity.revision.content["items"],
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
        activity.revision.content["choices"],
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
        if response_summary.activity_id == activity.resource_id do
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
           Map.get(responses_acc, response.question_id, 0) + response.count
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
        List.duplicate(
          %{
            value: r.selected_choice_points,
            choice: r.selected_choice_text,
            question: r.question,
            out_of: Map.get(responses_per_question_id, r.question_id, 0)
          },
          r.count
        )
      end)
      |> List.flatten()

    Map.merge(activity, %{
      datasets: %{
        medians: medians,
        values: values,
        questions_count: length(questions),
        axis_values: Enum.map(ordered_choices, fn c -> c.points end),
        first_choice_text: first_choice_text,
        last_choice_text: last_choice_text,
        title: activity.revision.title
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

  defp add_adaptive_input_details(
         activity_attempt,
         _response_summaries,
         adaptive_part_analytics,
         response_summaries_by_activity_part
       ) do
    parts_layout = activity_attempt.revision.content["partsLayout"] || []

    authored_parts =
      AdaptiveParts.authored_parts_by_id(activity_attempt.revision.content)

    resource_summaries = Map.get(activity_attempt, :resource_summaries, [])

    resource_summaries_by_part_id =
      Enum.reduce(resource_summaries, %{}, fn resource_summary, acc ->
        Map.put(acc, resource_summary.part_id, resource_summary)
      end)

    input_summaries =
      parts_layout
      |> Enum.with_index(1)
      |> Enum.filter(fn {part, _index} -> AdaptiveParts.scorable_part?(part) end)
      |> Enum.map(fn {part, index} ->
        part_id = Map.get(part, "id")
        part_definition = Map.merge(Map.get(authored_parts, part_id, %{}), part)
        resource_summary = Map.get(resource_summaries_by_part_id, part_id)
        grading_mode = adaptive_part_grading_mode(part_definition)

        part_analytics =
          Map.get(adaptive_part_analytics, {activity_attempt.resource_id, part_id})

        raw_responses =
          Map.get(
            response_summaries_by_activity_part,
            {activity_attempt.resource_id, part_id},
            []
          )

        responses =
          adaptive_summary_responses(
            activity_attempt.resource_id,
            part_id,
            grading_mode,
            response_summaries_by_activity_part,
            part_analytics
          )

        users =
          adaptive_summary_users(responses, grading_mode, part_analytics)

        correctness_metrics =
          adaptive_correctness_metrics(
            part_definition,
            responses,
            resource_summary,
            grading_mode,
            part_analytics
          )

        visualization =
          build_adaptive_visualization(
            part_definition,
            responses,
            resource_summary,
            adaptive_part_prompt(part_definition, index),
            grading_mode,
            part_analytics
          )
          |> Map.put(
            :fill_class,
            adaptive_visualization_fill_class(correctness_metrics)
          )

        %{
          part_id: part_id,
          label: adaptive_part_label(part_definition, index),
          component_type: adaptive_part_component_type_label(part_definition),
          grading_mode: adaptive_part_grading_mode(part_definition),
          grading_mode_label: adaptive_part_grading_mode_label(part_definition),
          evaluation_confidence: correctness_metrics.evaluation_confidence,
          prompt: adaptive_part_prompt(part_definition, index),
          response_count: Enum.reduce(responses, 0, &(&1.count + &2)),
          submitted_response_count: Enum.reduce(raw_responses, 0, &(&1.count + &2)),
          student_count: adaptive_student_count(users, grading_mode, part_analytics),
          attempt_count: adaptive_attempt_count(resource_summary, grading_mode, part_analytics),
          first_attempt_pct: correctness_metrics.first_attempt_pct,
          all_attempt_pct: correctness_metrics.all_attempt_pct,
          first_attempt_total_count: correctness_metrics.first_attempt_total_count,
          first_attempt_correct_count: correctness_metrics.first_attempt_correct_count,
          attempt_total_count: correctness_metrics.attempt_total_count,
          correct_count: correctness_metrics.correct_count,
          outcome_total_count: correctness_metrics.outcome_total_count,
          outcome_total_label: correctness_metrics.outcome_total_label,
          outcome_buckets: correctness_metrics.outcome_buckets,
          grading_pending: correctness_metrics.grading_pending,
          grading_pending_message: correctness_metrics.grading_pending_message,
          coverage_response_label: coverage_response_label(grading_mode),
          coverage_response_count:
            coverage_response_count(
              grading_mode,
              Enum.reduce(responses, 0, &(&1.count + &2)),
              correctness_metrics.first_attempt_total_count
            ),
          coverage_student_label: coverage_student_label(grading_mode),
          coverage_student_count:
            coverage_student_count(
              grading_mode,
              adaptive_student_count(users, grading_mode, part_analytics),
              part_analytics
            ),
          coverage_attempt_label: coverage_attempt_label(grading_mode),
          coverage_attempt_count:
            coverage_attempt_count(
              grading_mode,
              adaptive_attempt_count(resource_summary, grading_mode, part_analytics),
              correctness_metrics.first_attempt_total_count
            ),
          visualization: visualization,
          order: index
        }
      end)
      |> Enum.reject(&is_nil(&1.part_id))
      |> Enum.reject(
        &(&1.response_count == 0 and &1.student_count == 0 and &1.attempt_count == 0 and
            !(&1.grading_mode == :manual and &1.submitted_response_count > 0))
      )

    aggregate_metrics = aggregate_adaptive_activity_metrics(input_summaries)

    activity_attempt
    |> Map.put(:adaptive_input_summaries, input_summaries)
    |> Map.put(:first_attempt_pct, aggregate_metrics.first_attempt_pct)
    |> Map.put(:all_attempt_pct, aggregate_metrics.all_attempt_pct)
  end

  defp safe_percentage(nil, _numerator_key, _denominator_key), do: 0

  defp safe_percentage(summary, numerator_key, denominator_key) do
    numerator = Map.get(summary, numerator_key, 0)
    denominator = Map.get(summary, denominator_key, 0)

    if denominator > 0, do: numerator / denominator, else: 0
  end

  defp coverage_response_label(:manual), do: "First Input Responses"
  defp coverage_response_label(_), do: "Responses"

  defp coverage_response_count(:manual, _response_count, first_attempt_total_count),
    do: first_attempt_total_count

  defp coverage_response_count(_, response_count, _first_attempt_total_count), do: response_count

  defp coverage_student_label(_), do: "Unique Students who Responded"

  defp coverage_student_count(:manual, _student_count, %{first_attempt_student_ids: student_ids})
       when is_struct(student_ids, MapSet),
       do: MapSet.size(student_ids)

  defp coverage_student_count(:manual, student_count, _part_analytics), do: student_count
  defp coverage_student_count(_, student_count, _part_analytics), do: student_count

  defp coverage_attempt_label(:manual), do: "First Input Attempts"
  defp coverage_attempt_label(_), do: "Attempts"

  defp coverage_attempt_count(:manual, _attempt_count, first_attempt_total_count),
    do: first_attempt_total_count

  defp coverage_attempt_count(_, attempt_count, _first_attempt_total_count), do: attempt_count

  defp adaptive_part_label(part, index) do
    custom = Map.get(part, "custom", %{})

    Map.get(custom, "title") ||
      Map.get(custom, "name") ||
      Map.get(custom, "prompt") ||
      "Input #{index}"
  end

  defp adaptive_part_prompt(part, index) do
    custom = Map.get(part, "custom", %{})

    Map.get(custom, "label") ||
      Map.get(custom, "title") ||
      Map.get(custom, "prompt") ||
      adaptive_component_type_label(Map.get(part, "type")) <> " " <> Integer.to_string(index)
  end

  defp adaptive_component_type_label(nil), do: "Input"

  defp adaptive_component_type_label(type) do
    type
    |> String.replace_prefix("janus-", "")
    |> String.replace("-", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp adaptive_part_component_type_label(%{
         "type" => "janus-mcq",
         "custom" => %{"multipleSelection" => true}
       }),
       do: "Multiple Select"

  defp adaptive_part_component_type_label(part),
    do: adaptive_component_type_label(Map.get(part, "type"))

  defp adaptive_part_grading_mode(part) do
    part
    |> Map.get("gradingApproach", "automatic")
    |> case do
      "manual" -> :manual
      :manual -> :manual
      _ -> :automatic
    end
  end

  defp adaptive_part_grading_mode_label(part) do
    case adaptive_part_grading_mode(part) do
      :manual -> "Instructor Manual Grading"
      :automatic -> "Automatically Graded"
    end
  end

  defp adaptive_grading_badge_classes(:manual),
    do: "bg-amber-100 text-amber-800 dark:bg-amber-500/20 dark:text-amber-200"

  defp adaptive_grading_badge_classes(_mode),
    do: "bg-emerald-100 text-emerald-800 dark:bg-emerald-500/20 dark:text-emerald-200"

  defp adaptive_summary_responses(
         _activity_id,
         _part_id,
         _grading_mode,
         _response_summaries,
         %{first_attempt_responses: responses}
       )
       when is_list(responses),
       do: responses

  defp adaptive_summary_responses(
         _activity_id,
         _part_id,
         :manual,
         _response_summaries,
         part_analytics
       ) do
    case part_analytics do
      %{responses: responses} -> responses
      _ -> []
    end
  end

  defp adaptive_summary_responses(
         activity_id,
         part_id,
         _grading_mode,
         response_summaries_by_activity_part,
         _part_analytics
       ) do
    Map.get(response_summaries_by_activity_part, {activity_id, part_id}, [])
  end

  defp group_response_summaries_by_activity_part(response_summaries) do
    Enum.group_by(response_summaries, fn response_summary ->
      {response_summary.activity_id, response_summary.part_id}
    end)
  end

  defp adaptive_summary_users(_responses, :manual, %{student_ids: student_ids}), do: student_ids
  defp adaptive_summary_users(_responses, :manual, _part_analytics), do: []

  defp adaptive_summary_users(responses, _grading_mode, _part_analytics) do
    responses
    |> Enum.flat_map(&Map.get(&1, :users, []))
    |> Enum.uniq_by(&Map.get(&1, :id, OliWeb.Common.Utils.name(&1)))
  end

  defp adaptive_student_count(_users, _grading_mode, %{student_ids: student_ids})
       when is_struct(student_ids, MapSet),
       do: MapSet.size(student_ids)

  defp adaptive_student_count(_users, :manual, _part_analytics), do: 0
  defp adaptive_student_count(users, _grading_mode, _part_analytics), do: Enum.count(users)

  defp adaptive_attempt_count(_resource_summary, _grading_mode, %{attempt_count: attempt_count})
       when is_integer(attempt_count),
       do: attempt_count

  defp adaptive_attempt_count(_resource_summary, :manual, _part_analytics), do: 0

  defp adaptive_attempt_count(resource_summary, _grading_mode, _part_analytics),
    do: Map.get(resource_summary || %{}, :num_attempts, 0)

  defp build_adaptive_visualization(
         part,
         responses,
         resource_summary,
         prompt,
         grading_mode,
         part_analytics
       ) do
    case Map.get(part, "type") do
      "janus-mcq" ->
        build_adaptive_choice_distribution(
          part,
          responses,
          prompt,
          grading_mode,
          part_analytics
        )

      "janus-dropdown" ->
        build_adaptive_dropdown_distribution(
          part,
          responses,
          prompt,
          grading_mode,
          part_analytics
        )

      "janus-input-number" ->
        build_adaptive_numeric_distribution(part, responses, prompt)

      "janus-slider" ->
        build_adaptive_numeric_distribution(part, responses, prompt)

      "janus-text-slider" ->
        build_adaptive_numeric_distribution(part, responses, prompt)

      "janus-input-text" ->
        build_adaptive_response_patterns(
          prompt,
          responses,
          "Most common first-attempt text responses",
          "Each bar shows how often learners submitted the same text response for this input on their first attempt."
        )

      "janus-multi-line-text" ->
        build_adaptive_response_patterns(
          prompt,
          responses,
          "Most common first-attempt written responses",
          "Each bar shows how often learners submitted the same written response for this input on their first attempt."
        )

      "janus-formula" ->
        build_adaptive_response_patterns(
          prompt,
          responses,
          "Most common first-attempt formulas",
          "Each bar shows how often learners submitted the same formula for this input on their first attempt."
        )

      "janus-fill-blanks" ->
        build_adaptive_response_patterns(
          prompt,
          responses,
          "Most common first-attempt answer patterns",
          "Each bar shows how often learners submitted the same answer pattern across the blanks in this input on their first attempt."
        )

      _ ->
        build_adaptive_correctness_distribution(resource_summary, prompt)
    end
  end

  defp build_adaptive_response_patterns(prompt, responses, description, summary) do
    denominator =
      Enum.reduce(responses, 0, fn response_summary, total -> total + response_summary.count end)

    sorted_entries =
      responses
      |> Enum.map(fn response_summary ->
        label = adaptive_response_display_label(response_summary)

        %{
          label: label,
          supporting_text: adaptive_response_supporting_text(response_summary, label),
          count: response_summary.count,
          ratio: ratio(response_summary.count, denominator)
        }
      end)
      |> Enum.sort_by(fn entry -> {-entry.count, entry.label} end)

    unique_pattern_count = length(sorted_entries)
    entries = sorted_entries

    %{
      kind: :response_patterns,
      prompt: prompt,
      description: description,
      summary: summary,
      explanation:
        "Responses are grouped by identical normalized submission patterns, then ranked by frequency. Scroll to review the full set of grouped response patterns for this input.",
      unique_pattern_count: unique_pattern_count,
      denominator_count: denominator,
      entries: entries
    }
  end

  defp build_adaptive_numeric_distribution(part, responses, prompt) do
    entries = adaptive_numeric_distribution_entries(part, responses)

    denominator = Enum.reduce(entries, 0, fn entry, total -> total + entry.count end)

    if entries == [] or denominator == 0 do
      build_adaptive_response_patterns(
        prompt,
        responses,
        "First-attempt value patterns",
        "Each bar shows how often learners submitted the same value for this input on their first attempt."
      )
    else
      %{
        kind: :numeric_distribution,
        prompt: prompt,
        description: adaptive_numeric_description(part),
        scale_kind: adaptive_numeric_scale_kind(part),
        summary: adaptive_numeric_summary(part),
        denominator_count: denominator,
        scale_hint: adaptive_numeric_scale_hint(part),
        entries:
          Enum.map(entries, fn entry ->
            %{
              label: entry.label,
              step_label: Map.get(entry, :step_label),
              count: entry.count,
              ratio: ratio(entry.count, denominator)
            }
          end),
        stats: adaptive_numeric_stats(part, entries)
      }
    end
  end

  defp adaptive_numeric_distribution_entries(%{"type" => "janus-text-slider"} = part, responses) do
    labels = get_in(part, ["custom", "sliderOptionLabels"]) || []
    minimum = get_in(part, ["custom", "minimum"]) || 0

    counts_by_value =
      Enum.reduce(responses, %{}, fn response_summary, acc ->
        case adaptive_numeric_value(response_summary) do
          nil -> acc
          value -> Map.update(acc, value, response_summary.count, &(&1 + response_summary.count))
        end
      end)

    labels
    |> Enum.with_index(minimum)
    |> Enum.map(fn {label, index} ->
      numeric_value = index * 1.0

      %{
        label: label,
        step_label: adaptive_numeric_label(index),
        numeric_value: numeric_value,
        count: Map.get(counts_by_value, numeric_value, 0)
      }
    end)
  end

  defp adaptive_numeric_distribution_entries(part, responses) do
    responses
    |> Enum.map(fn response_summary ->
      case adaptive_numeric_value(response_summary) do
        nil ->
          nil

        value ->
          %{
            label: adaptive_numeric_entry_label(part, value),
            step_label: adaptive_numeric_entry_step_label(part, value),
            numeric_value: value,
            count: response_summary.count
          }
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.numeric_value)
  end

  defp adaptive_numeric_scale_kind(%{"type" => "janus-text-slider"}), do: :text_slider
  defp adaptive_numeric_scale_kind(%{"type" => "janus-slider"}), do: :slider
  defp adaptive_numeric_scale_kind(_), do: :numeric

  defp adaptive_numeric_summary(%{"type" => "janus-text-slider"}),
    do:
      "Each card shows how often learners landed on that labeled slider position on their first attempt."

  defp adaptive_numeric_summary(%{"type" => "janus-slider"}),
    do: "Each bar shows how often learners stopped on that slider value on their first attempt."

  defp adaptive_numeric_summary(_),
    do: "Each bar shows how often learners submitted that numeric value on their first attempt."

  defp adaptive_numeric_scale_hint(%{"type" => "janus-text-slider"} = part) do
    labels = get_in(part, ["custom", "sliderOptionLabels"]) || []

    case labels do
      [] ->
        nil

      _ ->
        %{
          min_label: List.first(labels),
          max_label: List.last(labels)
        }
    end
  end

  defp adaptive_numeric_scale_hint(%{"type" => "janus-slider"} = part) do
    %{
      min_label: adaptive_numeric_label(get_in(part, ["custom", "minimum"]) || 0),
      max_label: adaptive_numeric_label(get_in(part, ["custom", "maximum"]) || 0)
    }
  end

  defp adaptive_numeric_scale_hint(%{"type" => "janus-input-number"} = part) do
    %{
      min_label: adaptive_numeric_label(get_in(part, ["custom", "minValue"]) || 0),
      max_label: adaptive_numeric_label(get_in(part, ["custom", "maxValue"]) || 0)
    }
  end

  defp adaptive_numeric_scale_hint(_), do: nil

  defp adaptive_numeric_stats(%{"type" => "janus-text-slider"} = part, entries) do
    %{minimum: minimum, maximum: maximum, average: average} = adaptive_numeric_aggregate(entries)

    [
      adaptive_text_slider_stat("Lowest Selected", part, minimum),
      adaptive_text_slider_stat("Average Position", part, average),
      adaptive_text_slider_stat("Highest Selected", part, maximum)
    ]
  end

  defp adaptive_numeric_stats(_part, entries) do
    %{minimum: minimum, maximum: maximum, average: average} = adaptive_numeric_aggregate(entries)

    [
      %{label: "Minimum", value: adaptive_numeric_label(minimum)},
      %{
        label: "Average",
        value: adaptive_numeric_label(average)
      },
      %{label: "Maximum", value: adaptive_numeric_label(maximum)}
    ]
  end

  defp adaptive_numeric_aggregate(entries) do
    entries_with_responses = Enum.filter(entries, &(&1.count > 0))

    {weighted_sum, total_count, minimum, maximum} =
      Enum.reduce(entries_with_responses, {0.0, 0, nil, nil}, fn entry,
                                                                 {sum, count, min_v, max_v} ->
        numeric_value = entry.numeric_value

        {
          sum + numeric_value * entry.count,
          count + entry.count,
          if(is_nil(min_v), do: numeric_value, else: min(min_v, numeric_value)),
          if(is_nil(max_v), do: numeric_value, else: max(max_v, numeric_value))
        }
      end)

    %{
      minimum: minimum,
      maximum: maximum,
      average: weighted_sum / total_count
    }
  end

  defp adaptive_text_slider_stat(label, part, value) do
    rounded_value = Float.round(value)

    %{
      label: label,
      value:
        adaptive_text_slider_option_label(part, rounded_value) ||
          adaptive_numeric_label(rounded_value),
      supporting_text: "Position #{adaptive_numeric_label(rounded_value)}"
    }
  end

  defp build_adaptive_choice_distribution(part, responses, prompt, grading_mode, part_analytics) do
    config = Map.get(part, "custom", %{})
    choice_labels = extract_adaptive_choice_labels(config)
    correct_answers = Map.get(config, "correctAnswer", [])
    multiple_selection = Map.get(config, "multipleSelection", false)
    has_correctness_metadata = adaptive_mcq_has_correctness_metadata?(correct_answers)

    combination_entries =
      if multiple_selection do
        build_adaptive_mcq_combination_entries(
          responses,
          choice_labels,
          correct_answers
        )
      else
        []
      end

    counts =
      Enum.reduce(responses, %{}, fn response_summary, acc ->
        labels =
          response_summary.response
          |> decode_adaptive_response_tokens()
          |> resolve_adaptive_choice_labels(choice_labels)

        Enum.reduce(labels, acc, fn label, inner ->
          Map.update(inner, label, response_summary.count, &(&1 + response_summary.count))
        end)
      end)

    outcome_counts =
      adaptive_choice_outcome_counts(
        responses,
        choice_labels,
        grading_mode,
        part_analytics
      )

    denominator =
      if multiple_selection do
        Enum.reduce(counts, 0, fn {_label, count}, total -> total + count end)
      else
        Enum.reduce(responses, 0, fn response_summary, total -> total + response_summary.count end)
      end

    %{
      kind: :choice_distribution,
      multi_select: multiple_selection,
      selection_mode_label: if(multiple_selection, do: "Multiple Select", else: "Single Select"),
      prompt: prompt,
      description:
        if(multiple_selection,
          do: "First-attempt selections across responses",
          else: "First-attempt selected choice distribution"
        ),
      summary:
        if(multiple_selection,
          do:
            "Each bar shows how often learners included that option when responding to this input on their first attempt.",
          else: "Each bar shows how many learners selected that option on their first attempt."
        ),
      combination_summary:
        if(multiple_selection,
          do:
            "Outcomes for this input are based on the full combination of selected options, not on each option independently.",
          else: nil
        ),
      denominator_count: denominator,
      denominator_label: if(multiple_selection, do: "selections", else: "responses"),
      combination_denominator_count:
        Enum.reduce(responses, 0, fn response_summary, total -> total + response_summary.count end),
      authored_correct_combination:
        if(multiple_selection and has_correctness_metadata,
          do:
            adaptive_mcq_combination_label(
              correct_answers
              |> adaptive_mcq_correct_indexes()
              |> MapSet.to_list()
              |> Enum.sort(),
              choice_labels
            ),
          else: nil
        ),
      combination_entries: combination_entries,
      native_key_note:
        if(grading_mode == :manual and has_correctness_metadata,
          do:
            "Green answer-key badges show the native correct option. Credit-award badges show the recorded instructor grading decision.",
          else: nil
        ),
      choices:
        Enum.with_index(choice_labels)
        |> Enum.map(fn {label, index} ->
          count = Map.get(counts, label, 0)
          native_correct = Enum.at(correct_answers, index, false) == true

          correctness =
            adaptive_choice_correctness(
              grading_mode,
              has_correctness_metadata,
              native_correct,
              Map.get(outcome_counts, label, %{})
            )

          %{
            label: label,
            count: count,
            ratio: ratio(count, denominator),
            native_correct: native_correct,
            correctness: correctness,
            correct: correctness == true
          }
        end)
    }
  end

  defp build_adaptive_mcq_combination_entries(responses, choice_labels, correct_answers) do
    correct_indexes = adaptive_mcq_correct_indexes(correct_answers)
    has_correctness_metadata = adaptive_mcq_has_correctness_metadata?(correct_answers)

    denominator =
      Enum.reduce(responses, 0, fn response_summary, total -> total + response_summary.count end)

    responses
    |> Enum.reduce(%{}, fn response_summary, acc ->
      selected_indexes =
        response_summary.response
        |> decode_adaptive_response_tokens()
        |> Enum.map(&normalize_adaptive_choice_index/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.sort()

      key =
        case selected_indexes do
          [] -> "__no_answer__"
          _ -> Enum.join(selected_indexes, "|")
        end

      label = adaptive_mcq_combination_label(selected_indexes, choice_labels)

      Map.update(
        acc,
        key,
        %{
          label: label,
          count: response_summary.count,
          ratio: ratio(response_summary.count, denominator),
          correct:
            if(has_correctness_metadata,
              do: MapSet.equal?(MapSet.new(selected_indexes), correct_indexes),
              else: nil
            )
        },
        fn entry ->
          %{entry | count: entry.count + response_summary.count}
        end
      )
    end)
    |> Map.values()
    |> Enum.map(fn entry ->
      %{entry | ratio: ratio(entry.count, denominator)}
    end)
    |> Enum.sort_by(fn entry -> {-entry.count, entry.label} end)
    |> Enum.take(6)
  end

  defp build_adaptive_dropdown_distribution(
         part,
         responses,
         prompt,
         grading_mode,
         part_analytics
       ) do
    config = Map.get(part, "custom", %{})
    option_labels = Map.get(config, "optionLabels", [])
    correct_index = get_in(part, ["custom", "correctAnswer"]) |> normalize_adaptive_choice_index()
    has_correctness_metadata = not is_nil(correct_index)

    counts =
      Enum.reduce(responses, %{}, fn response_summary, acc ->
        labels =
          response_summary.response
          |> decode_adaptive_response_tokens()
          |> resolve_adaptive_choice_labels(option_labels)

        Enum.reduce(labels, acc, fn label, inner ->
          Map.update(inner, label, response_summary.count, &(&1 + response_summary.count))
        end)
      end)

    outcome_counts =
      adaptive_choice_outcome_counts(
        responses,
        option_labels,
        grading_mode,
        part_analytics
      )

    denominator =
      Enum.reduce(responses, 0, fn response_summary, total -> total + response_summary.count end)

    %{
      kind: :choice_distribution,
      prompt: prompt,
      description: "First-attempt selected option distribution",
      summary: "Each bar shows how many learners selected that option on their first attempt.",
      denominator_count: denominator,
      denominator_label: "responses",
      native_key_note:
        if(grading_mode == :manual and has_correctness_metadata,
          do:
            "Green answer-key badges show the native correct option. Credit-award badges show the recorded instructor grading decision.",
          else: nil
        ),
      choices:
        Enum.with_index(option_labels, 1)
        |> Enum.map(fn {label, index} ->
          count = Map.get(counts, label, 0)
          native_correct = correct_index == index

          correctness =
            adaptive_choice_correctness(
              grading_mode,
              has_correctness_metadata,
              native_correct,
              Map.get(outcome_counts, label, %{})
            )

          %{
            label: label,
            count: count,
            ratio: ratio(count, denominator),
            native_correct: native_correct,
            correctness: correctness,
            correct: correctness == true
          }
        end)
    }
  end

  defp build_adaptive_correctness_distribution(_resource_summary, prompt) do
    %{
      kind: :correctness_distribution,
      prompt: prompt,
      description: "Aggregate performance for this input",
      summary:
        "Use the outcome breakdown to see how often learners answer this input correctly on the first try, recover after retrying, or continue to struggle."
    }
  end

  defp adaptive_correctness_metrics(
         part,
         responses,
         resource_summary,
         grading_mode,
         part_analytics
       ) do
    cond do
      adaptive_manual_grading_pending?(grading_mode, part_analytics) ->
        adaptive_pending_manual_metrics()

      true ->
        student_based_metrics =
          adaptive_student_outcome_metrics(part, grading_mode, part_analytics)

        case student_based_metrics do
          nil ->
            adaptive_fallback_correctness_metrics(part, responses, resource_summary)

          metrics ->
            metrics
        end
    end
  end

  defp adaptive_manual_grading_pending?(:manual, nil), do: true
  defp adaptive_manual_grading_pending?(:manual, %{attempt_count: 0}), do: true
  defp adaptive_manual_grading_pending?(:manual, _part_analytics), do: false
  defp adaptive_manual_grading_pending?(_, _part_analytics), do: false

  defp adaptive_pending_manual_metrics do
    %{
      first_attempt_pct: 0,
      all_attempt_pct: 0,
      first_attempt_total_count: 0,
      first_attempt_correct_count: 0,
      attempt_total_count: 0,
      correct_count: 0,
      outcome_total_count: 0,
      outcome_total_label: "students",
      outcome_buckets: [],
      evaluation_confidence: :recorded,
      grading_pending: true,
      grading_pending_message:
        "No grading has been recorded for this manually graded input yet. Metrics will appear after instructor grading is saved."
    }
  end

  defp adaptive_fallback_correctness_metrics(part, responses, resource_summary) do
    case adaptive_recorded_correct_count(part, responses) do
      nil ->
        if adaptive_open_ended_missing_correctness?(part) do
          attempt_count =
            max(
              Map.get(resource_summary || %{}, :num_attempts, 0),
              Enum.reduce(responses, 0, fn response_summary, acc ->
                acc + response_summary.count
              end)
            )

          first_attempt_total =
            case Map.get(resource_summary || %{}, :num_first_attempts, 0) do
              0 -> attempt_count
              total -> total
            end

          retry_correct_count = max(attempt_count - first_attempt_total, 0)

          %{
            first_attempt_pct: ratio(first_attempt_total, first_attempt_total),
            all_attempt_pct: ratio(attempt_count, attempt_count),
            first_attempt_total_count: first_attempt_total,
            first_attempt_correct_count: first_attempt_total,
            attempt_total_count: attempt_count,
            correct_count: attempt_count,
            outcome_total_count: attempt_count,
            outcome_total_label: "attempts",
            outcome_buckets: [
              %{
                label: "Correct on first try",
                count: first_attempt_total,
                ratio: ratio(first_attempt_total, attempt_count),
                fill_class: "bg-sky-500 dark:bg-sky-400"
              },
              %{
                label: "Correct after retry",
                count: retry_correct_count,
                ratio: ratio(retry_correct_count, attempt_count),
                fill_class: "bg-cyan-500 dark:bg-cyan-400"
              },
              %{
                label: "Still incorrect",
                count: 0,
                ratio: 0,
                fill_class: "bg-slate-400 dark:bg-slate-500"
              }
            ],
            evaluation_confidence: :inferred,
            grading_pending: false,
            grading_pending_message: nil
          }
        else
          %{
            first_attempt_pct:
              safe_percentage(
                resource_summary,
                :num_first_attempts_correct,
                :num_first_attempts
              ),
            all_attempt_pct: safe_percentage(resource_summary, :num_correct, :num_attempts),
            first_attempt_total_count: Map.get(resource_summary || %{}, :num_first_attempts, 0),
            first_attempt_correct_count:
              Map.get(resource_summary || %{}, :num_first_attempts_correct, 0),
            attempt_total_count: Map.get(resource_summary || %{}, :num_attempts, 0),
            correct_count: Map.get(resource_summary || %{}, :num_correct, 0),
            outcome_total_count: Map.get(resource_summary || %{}, :num_attempts, 0),
            outcome_total_label: "attempts",
            outcome_buckets: adaptive_outcome_buckets(resource_summary),
            evaluation_confidence: :recorded,
            grading_pending: false,
            grading_pending_message: nil
          }
        end

      {source, correct_count} ->
        attempt_count =
          max(
            Map.get(resource_summary || %{}, :num_attempts, 0),
            Enum.reduce(responses, 0, fn response_summary, acc ->
              acc + response_summary.count
            end)
          )

        first_attempt_total =
          case Map.get(resource_summary || %{}, :num_first_attempts, 0) do
            0 -> attempt_count
            total -> total
          end

        correct_count = min(correct_count, attempt_count)

        first_try_count =
          adaptive_first_attempt_correct_count(
            part,
            resource_summary,
            source,
            correct_count,
            first_attempt_total,
            attempt_count
          )

        retry_correct_count = max(correct_count - first_try_count, 0)
        incorrect_count = max(attempt_count - correct_count, 0)

        %{
          first_attempt_pct: ratio(first_try_count, first_attempt_total),
          all_attempt_pct: ratio(correct_count, attempt_count),
          first_attempt_total_count: first_attempt_total,
          first_attempt_correct_count: first_try_count,
          attempt_total_count: attempt_count,
          correct_count: correct_count,
          outcome_total_count: attempt_count,
          outcome_total_label: "attempts",
          outcome_buckets: [
            %{
              label: "Correct on first try",
              count: first_try_count,
              ratio: ratio(first_try_count, attempt_count),
              fill_class: "bg-emerald-500 dark:bg-emerald-400"
            },
            %{
              label: "Correct after retry",
              count: retry_correct_count,
              ratio: ratio(retry_correct_count, attempt_count),
              fill_class: "bg-violet-500 dark:bg-violet-400"
            },
            %{
              label: "Still incorrect",
              count: incorrect_count,
              ratio: ratio(incorrect_count, attempt_count),
              fill_class: "bg-amber-500 dark:bg-amber-400"
            }
          ],
          evaluation_confidence: :recorded,
          grading_pending: false,
          grading_pending_message: nil
        }
    end
  end

  defp adaptive_student_outcome_metrics(_part, _grading_mode, nil), do: nil

  defp adaptive_student_outcome_metrics(part, _grading_mode, %{} = analytics) do
    student_count = adaptive_part_student_count(analytics)

    if student_count <= 0 do
      nil
    else
      first_attempt_correct_count =
        Map.get(
          analytics,
          :first_attempt_correct_student_count,
          Map.get(analytics, :first_attempt_correct_count, 0)
        )

      retry_correct_count =
        Map.get(
          analytics,
          :retry_correct_student_count,
          max(Map.get(analytics, :correct_student_count, 0) - first_attempt_correct_count, 0)
        )

      correct_count =
        Map.get(
          analytics,
          :correct_student_count,
          first_attempt_correct_count + retry_correct_count
        )

      incorrect_count =
        Map.get(
          analytics,
          :incorrect_student_count,
          max(student_count - correct_count, 0)
        )

      {correct_fill_class, retry_fill_class, incorrect_fill_class, confidence} =
        case adaptive_part_grading_mode(part) do
          :manual ->
            {"bg-emerald-500 dark:bg-emerald-400", "bg-violet-500 dark:bg-violet-400",
             "bg-amber-500 dark:bg-amber-400", :recorded}

          :automatic ->
            if adaptive_open_ended_missing_correctness?(part) or
                 adaptive_auto_choice_missing_correctness?(part) do
              {"bg-sky-500 dark:bg-sky-400", "bg-cyan-500 dark:bg-cyan-400",
               "bg-slate-400 dark:bg-slate-500", :inferred}
            else
              {"bg-emerald-500 dark:bg-emerald-400", "bg-violet-500 dark:bg-violet-400",
               "bg-amber-500 dark:bg-amber-400", :recorded}
            end
        end

      %{
        first_attempt_pct: ratio(first_attempt_correct_count, student_count),
        all_attempt_pct: ratio(correct_count, student_count),
        first_attempt_total_count: student_count,
        first_attempt_correct_count: first_attempt_correct_count,
        attempt_total_count: student_count,
        correct_count: correct_count,
        outcome_total_count: student_count,
        outcome_total_label: "students",
        outcome_buckets: [
          %{
            label: "Correct on first try",
            count: first_attempt_correct_count,
            ratio: ratio(first_attempt_correct_count, student_count),
            fill_class: correct_fill_class
          },
          %{
            label: "Correct after retry",
            count: retry_correct_count,
            ratio: ratio(retry_correct_count, student_count),
            fill_class: retry_fill_class
          },
          %{
            label: "Still incorrect",
            count: incorrect_count,
            ratio: ratio(incorrect_count, student_count),
            fill_class: incorrect_fill_class
          }
        ],
        evaluation_confidence: confidence,
        grading_pending: false,
        grading_pending_message: nil
      }
    end
  end

  defp adaptive_part_student_count(%{student_count: student_count})
       when is_integer(student_count),
       do: student_count

  defp adaptive_part_student_count(%{student_ids: %MapSet{} = student_ids}),
    do: MapSet.size(student_ids)

  defp adaptive_part_student_count(_analytics), do: 0

  defp adaptive_recorded_correct_count(part, responses) do
    case adaptive_choice_correct_count(part, responses) do
      nil ->
        case adaptive_open_ended_correct_count(part, responses) do
          nil -> nil
          correct_count -> {:open_ended, correct_count}
        end

      correct_count ->
        {:choice, correct_count}
    end
  end

  defp adaptive_first_attempt_correct_count(
         part,
         resource_summary,
         :choice,
         correct_count,
         first_attempt_total,
         attempt_count
       ) do
    if adaptive_auto_choice_missing_correctness?(part) do
      first_attempt_total
    else
      (resource_summary || %{})
      |> Map.get(:num_first_attempts_correct, 0)
      |> min(correct_count)
      |> min(first_attempt_total)
      |> min(attempt_count)
    end
  end

  defp adaptive_first_attempt_correct_count(
         _part,
         resource_summary,
         :open_ended,
         correct_count,
         first_attempt_total,
         _attempt_count
       ) do
    case resource_summary do
      %{num_first_attempts_correct: first_attempt_correct_count} ->
        first_attempt_correct_count
        |> min(correct_count)
        |> min(first_attempt_total)

      _ ->
        min(correct_count, first_attempt_total)
    end
  end

  defp adaptive_choice_correct_count(part, responses) do
    case {adaptive_part_grading_mode(part), Map.get(part, "type")} do
      {:automatic, "janus-mcq"} ->
        total_count =
          Enum.reduce(responses, 0, fn response_summary, acc -> acc + response_summary.count end)

        correct_indexes =
          part
          |> get_in(["custom", "correctAnswer"])
          |> List.wrap()
          |> Enum.with_index(1)
          |> Enum.flat_map(fn
            {true, index} -> [Integer.to_string(index)]
            _ -> []
          end)
          |> MapSet.new()

        multiple_selection = get_in(part, ["custom", "multipleSelection"]) == true

        if MapSet.size(correct_indexes) == 0 do
          total_count
        else
          Enum.reduce(responses, 0, fn response_summary, acc ->
            if adaptive_mcq_response_correct?(
                 response_summary.response,
                 correct_indexes,
                 multiple_selection
               ) do
              acc + response_summary.count
            else
              acc
            end
          end)
        end

      {:automatic, "janus-dropdown"} ->
        total_count =
          Enum.reduce(responses, 0, fn response_summary, acc -> acc + response_summary.count end)

        correct_index =
          part
          |> get_in(["custom", "correctAnswer"])
          |> normalize_adaptive_choice_index()

        if is_nil(correct_index) do
          total_count
        else
          Enum.reduce(responses, 0, fn response_summary, acc ->
            tokens = decode_adaptive_response_tokens(response_summary.response)

            if tokens == [Integer.to_string(correct_index)] do
              acc + response_summary.count
            else
              acc
            end
          end)
        end

      _ ->
        nil
    end
  end

  defp adaptive_open_ended_correct_count(part, responses) do
    with :automatic <- adaptive_part_grading_mode(part),
         criteria when not is_nil(criteria) <- adaptive_open_ended_criteria(part) do
      Enum.reduce(responses, 0, fn response_summary, acc ->
        if adaptive_open_ended_response_correct?(criteria, response_summary) do
          acc + response_summary.count
        else
          acc
        end
      end)
    else
      _ -> nil
    end
  end

  defp adaptive_open_ended_missing_correctness?(part) do
    adaptive_part_grading_mode(part) == :automatic and
      Map.get(part, "type") in [
        "janus-input-text",
        "janus-multi-line-text",
        "janus-input-number",
        "janus-slider",
        "janus-text-slider",
        "janus-fill-blanks",
        "janus-formula"
      ] and
      is_nil(adaptive_open_ended_criteria(part))
  end

  defp adaptive_open_ended_criteria(part) do
    custom = Map.get(part, "custom", %{})

    case Map.get(part, "type") do
      "janus-input-text" ->
        build_adaptive_text_criteria(Map.get(custom, "correctAnswer", %{}))

      "janus-multi-line-text" ->
        build_adaptive_multiline_criteria(custom)

      "janus-input-number" ->
        build_adaptive_numeric_criteria(Map.get(custom, "answer"))

      "janus-slider" ->
        build_adaptive_numeric_criteria(Map.get(custom, "answer"))

      "janus-text-slider" ->
        build_adaptive_numeric_criteria(Map.get(custom, "answer"))

      _ ->
        nil
    end
  end

  defp build_adaptive_text_criteria(correct_answer) when is_map(correct_answer) do
    required_terms =
      correct_answer
      |> Map.get("mustContain", "")
      |> split_adaptive_text_criteria_terms()

    forbidden_terms =
      correct_answer
      |> Map.get("mustNotContain", "")
      |> split_adaptive_text_criteria_terms()

    minimum_length =
      correct_answer
      |> Map.get("minimumLength", 0)
      |> normalize_adaptive_integer()
      |> Kernel.||(0)

    if required_terms == [] and forbidden_terms == [] and minimum_length <= 0 do
      nil
    else
      %{
        kind: :text,
        required_terms: required_terms,
        forbidden_terms: forbidden_terms,
        minimum_length: minimum_length
      }
    end
  end

  defp build_adaptive_text_criteria(_), do: nil

  defp build_adaptive_multiline_criteria(custom) when is_map(custom) do
    minimum_length =
      custom
      |> Map.get("minimumLength", 0)
      |> normalize_adaptive_integer()
      |> Kernel.||(0)

    if minimum_length > 0 do
      %{kind: :multiline, minimum_length: minimum_length}
    else
      nil
    end
  end

  defp build_adaptive_multiline_criteria(_), do: nil

  defp build_adaptive_numeric_criteria(answer) when is_map(answer) do
    cond do
      Map.get(answer, "range") == true ->
        min_value = normalize_adaptive_float(Map.get(answer, "correctMin"))
        max_value = normalize_adaptive_float(Map.get(answer, "correctMax"))

        if is_nil(min_value) or is_nil(max_value) do
          nil
        else
          %{kind: :numeric_range, min: min_value, max: max_value}
        end

      true ->
        case normalize_adaptive_float(Map.get(answer, "correctAnswer")) do
          nil -> nil
          value -> %{kind: :numeric_exact, value: value}
        end
    end
  end

  defp build_adaptive_numeric_criteria(_), do: nil

  defp adaptive_open_ended_response_correct?(%{kind: :text} = criteria, response_summary) do
    case adaptive_text_response_value(response_summary) do
      nil ->
        false

      response ->
        String.length(response) >= criteria.minimum_length and
          Enum.all?(criteria.required_terms, &String.contains?(response, &1)) and
          Enum.all?(criteria.forbidden_terms, &(not String.contains?(response, &1)))
    end
  end

  defp adaptive_open_ended_response_correct?(%{kind: :multiline} = criteria, response_summary) do
    case adaptive_text_response_value(response_summary) do
      nil -> false
      response -> String.length(response) >= criteria.minimum_length
    end
  end

  defp adaptive_open_ended_response_correct?(
         %{kind: :numeric_exact, value: expected},
         response_summary
       ) do
    case adaptive_numeric_response_value(response_summary) do
      nil -> false
      value -> abs(value - expected) < 1.0e-9
    end
  end

  defp adaptive_open_ended_response_correct?(
         %{kind: :numeric_range, min: min_value, max: max_value},
         response_summary
       ) do
    case adaptive_numeric_response_value(response_summary) do
      nil -> false
      value -> value >= min_value and value <= max_value
    end
  end

  defp split_adaptive_text_criteria_terms(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_adaptive_text_criteria_terms(_), do: []

  defp adaptive_text_response_value(response_summary) do
    first_present([
      blank_to_nil(Map.get(response_summary, :response)),
      blank_to_nil(Map.get(response_summary, :label))
    ])
  end

  defp adaptive_numeric_response_value(response_summary) do
    first_present([
      blank_to_nil(Map.get(response_summary, :response)),
      blank_to_nil(Map.get(response_summary, :label))
    ])
    |> case do
      nil ->
        nil

      value ->
        value
        |> String.replace(~r/[,%]/, "")
        |> Float.parse()
        |> case do
          {numeric_value, ""} -> numeric_value
          _ -> nil
        end
    end
  end

  defp normalize_adaptive_integer(value) when is_integer(value), do: value

  defp normalize_adaptive_integer(value) when is_float(value) do
    trunc(value)
  end

  defp normalize_adaptive_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp normalize_adaptive_integer(_), do: nil

  defp normalize_adaptive_float(value) when is_integer(value), do: value * 1.0
  defp normalize_adaptive_float(value) when is_float(value), do: value

  defp normalize_adaptive_float(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {parsed, ""} -> parsed
      _ -> nil
    end
  end

  defp normalize_adaptive_float(_), do: nil

  defp adaptive_mcq_has_correctness_metadata?(correct_answers) do
    correct_answers
    |> List.wrap()
    |> Enum.any?(fn answer -> answer in [true, false] end)
  end

  defp adaptive_mcq_correct_indexes(correct_answers) do
    correct_answers
    |> List.wrap()
    |> Enum.with_index(1)
    |> Enum.flat_map(fn
      {true, index} -> [index]
      _ -> []
    end)
    |> MapSet.new()
  end

  defp adaptive_mcq_combination_label([], _choice_labels), do: "No answer"

  defp adaptive_mcq_combination_label(selected_indexes, choice_labels) do
    selected_indexes
    |> Enum.map(fn index ->
      Enum.at(choice_labels, index - 1) || "Option #{index}"
    end)
    |> Enum.join(" + ")
  end

  defp adaptive_auto_choice_missing_correctness?(part) do
    case {adaptive_part_grading_mode(part), Map.get(part, "type")} do
      {:automatic, "janus-mcq"} ->
        not adaptive_mcq_has_correctness_metadata?(get_in(part, ["custom", "correctAnswer"]))

      {:automatic, "janus-dropdown"} ->
        is_nil(get_in(part, ["custom", "correctAnswer"]) |> normalize_adaptive_choice_index())

      _ ->
        false
    end
  end

  defp adaptive_choice_outcome_counts(responses, choice_labels, :automatic, _part_analytics) do
    Enum.reduce(responses, %{}, fn response_summary, acc ->
      labels =
        response_summary.response
        |> decode_adaptive_response_tokens()
        |> resolve_adaptive_choice_labels(choice_labels)

      Enum.reduce(labels, acc, fn label, inner ->
        Map.update(
          inner,
          label,
          %{
            correct: Map.get(response_summary, :correct_count, 0),
            incorrect: Map.get(response_summary, :incorrect_count, 0),
            partial: Map.get(response_summary, :partial_count, 0)
          },
          fn counts ->
            %{
              correct: counts.correct + Map.get(response_summary, :correct_count, 0),
              incorrect: counts.incorrect + Map.get(response_summary, :incorrect_count, 0),
              partial: counts.partial + Map.get(response_summary, :partial_count, 0)
            }
          end
        )
      end)
    end)
  end

  defp adaptive_choice_outcome_counts(responses, choice_labels, :manual, _part_analytics) do
    Enum.reduce(responses, %{}, fn response_summary, acc ->
      labels =
        response_summary.response
        |> decode_adaptive_response_tokens()
        |> resolve_adaptive_choice_labels(choice_labels)

      Enum.reduce(labels, acc, fn label, inner ->
        Map.update(
          inner,
          label,
          %{
            correct: Map.get(response_summary, :correct_count, 0),
            incorrect: Map.get(response_summary, :incorrect_count, 0),
            partial: Map.get(response_summary, :partial_count, 0)
          },
          fn counts ->
            %{
              correct: counts.correct + Map.get(response_summary, :correct_count, 0),
              incorrect: counts.incorrect + Map.get(response_summary, :incorrect_count, 0),
              partial: counts.partial + Map.get(response_summary, :partial_count, 0)
            }
          end
        )
      end)
    end)
  end

  defp adaptive_choice_correctness(
         :automatic,
         has_correctness_metadata,
         explicit_correct,
         outcome_counts
       ) do
    case adaptive_choice_correctness_from_outcomes(outcome_counts) do
      nil ->
        adaptive_choice_correctness_without_recorded_outcomes(
          has_correctness_metadata,
          explicit_correct,
          outcome_counts
        )

      correctness ->
        correctness
    end
  end

  defp adaptive_choice_correctness(
         :manual,
         _has_correctness_metadata,
         _explicit_correct,
         outcome_counts
       ) do
    adaptive_choice_correctness_from_outcomes(outcome_counts)
  end

  defp adaptive_choice_correctness_from_outcomes(outcome_counts) do
    correct = Map.get(outcome_counts, :correct, 0)
    incorrect = Map.get(outcome_counts, :incorrect, 0)
    partial = Map.get(outcome_counts, :partial, 0)

    cond do
      partial > 0 -> :partial
      correct > 0 and incorrect > 0 -> :partial
      correct > 0 -> true
      incorrect > 0 -> false
      true -> nil
    end
  end

  defp adaptive_choice_correctness_without_recorded_outcomes(
         has_correctness_metadata,
         explicit_correct,
         outcome_counts
       ) do
    if adaptive_choice_outcomes_recorded?(outcome_counts) do
      nil
    else
      case {has_correctness_metadata, explicit_correct} do
        {false, _} -> true
        {true, true} -> true
        {true, false} -> false
      end
    end
  end

  defp adaptive_choice_outcomes_recorded?(outcome_counts) do
    Map.get(outcome_counts, :correct, 0) > 0 or
      Map.get(outcome_counts, :incorrect, 0) > 0 or
      Map.get(outcome_counts, :partial, 0) > 0
  end

  defp adaptive_mcq_response_correct?(response, correct_indexes, multiple_selection) do
    selected =
      response
      |> decode_adaptive_response_tokens()
      |> MapSet.new()

    if multiple_selection do
      MapSet.equal?(selected, correct_indexes)
    else
      MapSet.size(selected) == 1 and MapSet.equal?(selected, correct_indexes)
    end
  end

  defp normalize_adaptive_choice_index(value) when is_integer(value) and value > 0, do: value

  defp normalize_adaptive_choice_index(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> nil
    end
  end

  defp normalize_adaptive_choice_index(_), do: nil

  defp classify_manual_score(score, out_of) do
    out_of =
      case out_of do
        nil -> 1.0
        0 -> 1.0
        value -> value
      end

    cond do
      score <= 0 -> :incorrect
      score >= out_of -> :correct
      true -> :partial
    end
  end

  defp fetch_adaptive_part_analytics(
         section_id,
         revisions_by_resource_id,
         activity_types_map
       ) do
    adaptive_type_id =
      Enum.find_value(activity_types_map, fn {id, registration} ->
        if Map.get(registration, :slug) == "oli_adaptive", do: id
      end)

    adaptive_activity_ids =
      revisions_by_resource_id
      |> Enum.filter(fn {_resource_id, revision} ->
        revision.activity_type_id == adaptive_type_id
      end)
      |> Enum.map(fn {resource_id, _revision} -> resource_id end)

    if adaptive_activity_ids == [] do
      %{}
    else
      query =
        from(aa in ActivityAttempt,
          join: pa1 in PartAttempt,
          on: aa.id == pa1.activity_attempt_id,
          left_join: pa2 in PartAttempt,
          on:
            pa1.activity_attempt_id == pa2.activity_attempt_id and pa1.part_id == pa2.part_id and
              pa1.id < pa2.id,
          join: ra in ResourceAttempt,
          on: ra.id == aa.resource_attempt_id,
          join: rac in ResourceAccess,
          on: rac.id == ra.resource_access_id,
          join: revision in Revision,
          on: revision.id == aa.revision_id,
          where: rac.section_id == ^section_id,
          where: aa.resource_id in ^adaptive_activity_ids,
          where: is_nil(pa2),
          where: pa1.lifecycle_state == :evaluated,
          order_by: [
            asc: rac.user_id,
            asc: aa.attempt_number,
            asc: pa1.attempt_number,
            asc: pa1.id
          ],
          select: %{
            activity_id: aa.resource_id,
            activity_attempt_number: aa.attempt_number,
            user_id: rac.user_id,
            part_attempt: pa1,
            revision: revision
          }
        )

      Repo.transaction(fn ->
        query
        |> Repo.stream()
        |> Enum.reduce(%{}, fn row, acc ->
          accumulate_adaptive_part_analytics_row(acc, row)
        end)
        |> finalize_adaptive_part_analytics()
      end)
      |> case do
        {:ok, analytics} -> analytics
        _ -> %{}
      end
    end
  end

  defp accumulate_adaptive_part_analytics_row(acc, row) do
    part_attempt = Map.put(row.part_attempt, :activity_revision, row.revision)
    part = AdaptiveParts.part_definition(row.revision.content, part_attempt.part_id)

    if is_nil(part) or not AdaptiveParts.scorable_part?(part) do
      acc
    else
      response_label = ResponseLabel.build(part_attempt, "oli_adaptive")
      key = {row.activity_id, part_attempt.part_id}
      score_classification = classify_adaptive_part_attempt(part, part_attempt, response_label)

      if score_classification == :skipped do
        acc
      else
        correct = score_classification == :correct

        response_entry = %{
          activity_id: row.activity_id,
          part_id: part_attempt.part_id,
          response: response_label.response,
          label: response_label.label,
          count: 1,
          users: [],
          correct_count: if(score_classification == :correct, do: 1, else: 0),
          incorrect_count: if(score_classification == :incorrect, do: 1, else: 0),
          partial_count: if(score_classification == :partial, do: 1, else: 0)
        }

        Map.update(
          acc,
          key,
          %{
            responses_by_key: %{response_entry.response => response_entry},
            response_order: [response_entry.response],
            first_attempt_responses_by_key: %{response_entry.response => response_entry},
            first_attempt_response_order: [response_entry.response],
            student_ids: MapSet.new([row.user_id]),
            first_attempt_student_ids: MapSet.new([row.user_id]),
            student_outcomes: %{
              row.user_id => %{
                first_attempt_number: row.activity_attempt_number,
                first_correct: correct,
                ever_correct: correct
              }
            },
            attempt_count: 1,
            correct_count: if(correct, do: 1, else: 0),
            first_attempt_count: 1,
            first_attempt_correct_count: if(correct, do: 1, else: 0)
          },
          fn analytics ->
            first_attempt = not Map.has_key?(analytics.student_outcomes, row.user_id)

            %{
              analytics
              | responses_by_key:
                  merge_manual_response_counts(
                    analytics.responses_by_key,
                    response_entry
                  ),
                response_order:
                  if(
                    Map.has_key?(analytics.responses_by_key, response_entry.response),
                    do: analytics.response_order,
                    else: analytics.response_order ++ [response_entry.response]
                  ),
                first_attempt_responses_by_key:
                  if(
                    first_attempt,
                    do:
                      merge_manual_response_counts(
                        analytics.first_attempt_responses_by_key,
                        response_entry
                      ),
                    else: analytics.first_attempt_responses_by_key
                  ),
                first_attempt_response_order:
                  if(
                    first_attempt and
                      not Map.has_key?(
                        analytics.first_attempt_responses_by_key,
                        response_entry.response
                      ),
                    do: analytics.first_attempt_response_order ++ [response_entry.response],
                    else: analytics.first_attempt_response_order
                  ),
                student_ids: MapSet.put(analytics.student_ids, row.user_id),
                first_attempt_student_ids:
                  if(
                    first_attempt,
                    do: MapSet.put(analytics.first_attempt_student_ids, row.user_id),
                    else: analytics.first_attempt_student_ids
                  ),
                student_outcomes:
                  Map.update(
                    analytics.student_outcomes,
                    row.user_id,
                    %{
                      first_attempt_number: row.activity_attempt_number,
                      first_correct: correct,
                      ever_correct: correct
                    },
                    fn outcome ->
                      %{outcome | ever_correct: outcome.ever_correct or correct}
                    end
                  ),
                attempt_count: analytics.attempt_count + 1,
                correct_count: analytics.correct_count + if(correct, do: 1, else: 0),
                first_attempt_count:
                  analytics.first_attempt_count + if(first_attempt, do: 1, else: 0),
                first_attempt_correct_count:
                  analytics.first_attempt_correct_count +
                    if(first_attempt and correct, do: 1, else: 0)
            }
          end
        )
      end
    end
  end

  defp classify_adaptive_part_attempt(part, part_attempt, response_label) do
    case adaptive_part_grading_mode(part) do
      :manual ->
        case part_attempt.score do
          nil -> :skipped
          score -> classify_manual_score(score, part_attempt.out_of)
        end

      :automatic ->
        response_summary = %{
          response: response_label.response,
          label: response_label.label,
          count: 1
        }

        cond do
          adaptive_recorded_score_meaningful?(part_attempt) ->
            classify_manual_score(part_attempt.score, part_attempt.out_of)

          adaptive_choice_correct_count(part, [response_summary]) == 1 ->
            :correct

          adaptive_choice_correct_count(part, [response_summary]) == 0 ->
            :incorrect

          adaptive_open_ended_correct_count(part, [response_summary]) == 1 ->
            :correct

          adaptive_open_ended_correct_count(part, [response_summary]) == 0 ->
            :incorrect

          adaptive_auto_choice_missing_correctness?(part) or
              adaptive_open_ended_missing_correctness?(part) ->
            :correct

          true ->
            :incorrect
        end
    end
  end

  defp adaptive_recorded_score_meaningful?(%{score: score, out_of: out_of})
       when is_number(score) and is_number(out_of),
       do: out_of > 0

  defp adaptive_recorded_score_meaningful?(_), do: false

  defp finalize_adaptive_part_analytics(analytics_by_part) do
    Enum.into(analytics_by_part, %{}, fn {key, analytics} ->
      student_outcomes = Map.get(analytics, :student_outcomes, %{})

      first_attempt_correct_student_count =
        Enum.count(student_outcomes, fn {_user_id, outcome} -> outcome.first_correct end)

      retry_correct_student_count =
        Enum.count(student_outcomes, fn {_user_id, outcome} ->
          not outcome.first_correct and outcome.ever_correct
        end)

      correct_student_count = first_attempt_correct_student_count + retry_correct_student_count
      student_count = map_size(student_outcomes)
      incorrect_student_count = max(student_count - correct_student_count, 0)

      {
        key,
        analytics
        |> Map.put(
          :responses,
          Enum.map(Map.get(analytics, :response_order, []), fn response_key ->
            Map.fetch!(analytics.responses_by_key, response_key)
          end)
        )
        |> Map.put(
          :first_attempt_responses,
          Enum.map(Map.get(analytics, :first_attempt_response_order, []), fn response_key ->
            Map.fetch!(analytics.first_attempt_responses_by_key, response_key)
          end)
        )
        |> Map.delete(:responses_by_key)
        |> Map.delete(:response_order)
        |> Map.delete(:first_attempt_responses_by_key)
        |> Map.delete(:first_attempt_response_order)
        |> Map.put(:student_count, student_count)
        |> Map.put(:first_attempt_correct_student_count, first_attempt_correct_student_count)
        |> Map.put(:retry_correct_student_count, retry_correct_student_count)
        |> Map.put(:correct_student_count, correct_student_count)
        |> Map.put(:incorrect_student_count, incorrect_student_count)
      }
    end)
  end

  defp merge_manual_response_counts(existing, incoming) do
    Map.update(existing, incoming.response, incoming, fn response ->
      %{
        response
        | count: response.count + incoming.count,
          label: Map.get(response, :label) || Map.get(incoming, :label),
          correct_count:
            Map.get(response, :correct_count, 0) + Map.get(incoming, :correct_count, 0),
          incorrect_count:
            Map.get(response, :incorrect_count, 0) + Map.get(incoming, :incorrect_count, 0),
          partial_count:
            Map.get(response, :partial_count, 0) + Map.get(incoming, :partial_count, 0)
      }
    end)
  end

  defp adaptive_outcome_buckets(resource_summary) do
    first_try_count = Map.get(resource_summary || %{}, :num_first_attempts_correct, 0)
    correct_count = Map.get(resource_summary || %{}, :num_correct, 0)
    attempt_count = Map.get(resource_summary || %{}, :num_attempts, 0)
    retry_correct_count = max(correct_count - first_try_count, 0)
    incorrect_count = max(attempt_count - correct_count, 0)

    [
      %{
        label: "Correct on first try",
        count: first_try_count,
        ratio: ratio(first_try_count, attempt_count),
        fill_class: "bg-emerald-500 dark:bg-emerald-400"
      },
      %{
        label: "Correct after retry",
        count: retry_correct_count,
        ratio: ratio(retry_correct_count, attempt_count),
        fill_class: "bg-violet-500 dark:bg-violet-400"
      },
      %{
        label: "Still incorrect",
        count: incorrect_count,
        ratio: ratio(incorrect_count, attempt_count),
        fill_class: "bg-amber-500 dark:bg-amber-400"
      }
    ]
  end

  defp aggregate_adaptive_activity_metrics(input_summaries) do
    totals =
      Enum.reduce(
        input_summaries,
        %{first_attempt_total: 0, first_attempt_correct: 0, attempts: 0, correct: 0},
        fn summary, acc ->
          if Map.get(summary, :grading_pending, false) do
            acc
          else
            %{
              first_attempt_total:
                acc.first_attempt_total + Map.get(summary, :first_attempt_total_count, 0),
              first_attempt_correct:
                acc.first_attempt_correct + Map.get(summary, :first_attempt_correct_count, 0),
              attempts: acc.attempts + Map.get(summary, :attempt_total_count, 0),
              correct: acc.correct + Map.get(summary, :correct_count, 0)
            }
          end
        end
      )

    %{
      first_attempt_pct: ratio(totals.first_attempt_correct, totals.first_attempt_total),
      all_attempt_pct: ratio(totals.correct, totals.attempts)
    }
  end

  defp extract_adaptive_choice_labels(config) do
    Map.get(config, "mcqItems", [])
    |> Enum.map(fn item ->
      item
      |> Map.get("nodes", [])
      |> extract_adaptive_rich_text()
      |> blank_to_nil()
      |> case do
        nil -> "Option"
        label -> label
      end
    end)
  end

  defp extract_adaptive_rich_text(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&extract_adaptive_rich_text/1)
    |> Enum.join("")
  end

  defp extract_adaptive_rich_text(%{"text" => text}) when is_binary(text), do: text

  defp extract_adaptive_rich_text(%{"children" => children}) when is_list(children),
    do: extract_adaptive_rich_text(children)

  defp extract_adaptive_rich_text(%{"nodes" => nodes}) when is_list(nodes),
    do: extract_adaptive_rich_text(nodes)

  defp extract_adaptive_rich_text(%{"content" => content}) when is_list(content),
    do: extract_adaptive_rich_text(content)

  defp extract_adaptive_rich_text(_), do: ""

  defp decode_adaptive_response_tokens(nil), do: []

  defp decode_adaptive_response_tokens(response) when is_binary(response) do
    trimmed = String.trim(response)

    cond do
      trimmed == "" ->
        []

      true ->
        case Jason.decode(trimmed) do
          {:ok, decoded} -> normalize_adaptive_response_tokens(decoded)
          _ -> normalize_adaptive_response_tokens(trimmed)
        end
    end
  end

  defp decode_adaptive_response_tokens(response),
    do: normalize_adaptive_response_tokens(response)

  defp adaptive_response_display_label(response_summary) do
    first_present([
      Map.get(response_summary, :label),
      blank_to_nil(Map.get(response_summary, :response))
    ]) || "No response"
  end

  defp adaptive_response_supporting_text(response_summary, display_label) do
    raw_response = blank_to_nil(Map.get(response_summary, :response))
    label = blank_to_nil(Map.get(response_summary, :label))

    cond do
      is_nil(raw_response) ->
        nil

      is_nil(label) ->
        nil

      raw_response == display_label ->
        nil

      raw_response == label ->
        nil

      true ->
        "Recorded value: #{raw_response}"
    end
  end

  defp adaptive_numeric_value(response_summary) do
    response_summary
    |> adaptive_response_display_label()
    |> String.replace(~r/[,%]/, "")
    |> blank_to_nil()
    |> case do
      nil ->
        nil

      value ->
        case Float.parse(value) do
          {numeric_value, ""} -> numeric_value
          _ -> nil
        end
    end
  end

  defp adaptive_numeric_description(part) do
    case Map.get(part, "type") do
      "janus-slider" -> "First-attempt ordered slider value distribution"
      "janus-text-slider" -> "First-attempt ordered text slider value distribution"
      _ -> "First-attempt ordered numeric response distribution"
    end
  end

  defp adaptive_numeric_label(value) when is_integer(value), do: Integer.to_string(value)

  defp adaptive_numeric_label(value) when is_float(value) do
    if Float.floor(value) == value do
      value |> round() |> Integer.to_string()
    else
      :erlang.float_to_binary(value, decimals: 2)
    end
  end

  defp adaptive_numeric_entry_label(part, value) do
    case adaptive_text_slider_option_label(part, value) do
      nil -> adaptive_numeric_label(value)
      label -> label
    end
  end

  defp adaptive_numeric_entry_step_label(%{"type" => "janus-slider"}, value),
    do: "Value #{adaptive_numeric_label(value)}"

  defp adaptive_numeric_entry_step_label(%{"type" => "janus-input-number"}, value),
    do: "Value #{adaptive_numeric_label(value)}"

  defp adaptive_numeric_entry_step_label(_part, _value), do: nil

  defp adaptive_text_slider_option_label(%{"type" => "janus-text-slider"} = part, value) do
    config = Map.get(part, "custom", %{})
    labels = Map.get(config, "sliderOptionLabels", [])
    minimum = Map.get(config, "minimum", 0)

    case normalize_adaptive_integer(value) do
      nil -> nil
      index -> Enum.at(labels, index - minimum)
    end
  end

  defp adaptive_text_slider_option_label(_part, _value), do: nil

  defp normalize_adaptive_response_tokens(value) when is_list(value) do
    Enum.flat_map(value, &normalize_adaptive_response_tokens/1)
  end

  defp normalize_adaptive_response_tokens(value) when is_integer(value),
    do: [Integer.to_string(value)]

  defp normalize_adaptive_response_tokens(value) when is_float(value),
    do: [to_string(round(value))]

  defp normalize_adaptive_response_tokens(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_adaptive_response_tokens(%{"input" => input}),
    do: normalize_adaptive_response_tokens(input)

  defp normalize_adaptive_response_tokens(%{input: input}),
    do: normalize_adaptive_response_tokens(input)

  defp normalize_adaptive_response_tokens(_), do: []

  defp resolve_adaptive_choice_labels(tokens, labels) do
    tokens
    |> Enum.map(fn token ->
      cond do
        token in labels ->
          token

        is_integer_string?(token) ->
          token
          |> String.to_integer()
          |> then(fn index -> Enum.at(labels, index - 1) end)

        true ->
          Enum.find(labels, fn label -> String.contains?(token, label) end)
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp is_integer_string?(value) when is_binary(value) do
    case Integer.parse(value) do
      {_, ""} -> true
      _ -> false
    end
  end

  defp ratio(_count, denominator) when denominator <= 0, do: 0
  defp ratio(count, denominator), do: count / denominator

  defp first_present(values) do
    Enum.find(values, fn value -> not is_nil(blank_to_nil(value)) end)
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  # This is only used by the multi-input
  defp update_choices_frequencies(activity_attempt, response_summaries) do
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

  defp add_dropdown_choices(acc, response_summaries) do
    update_choices_frequencies(acc, response_summaries)
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
            users: Enum.map(response_summary.users, fn u -> OliWeb.Common.Utils.name(u) end),
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
