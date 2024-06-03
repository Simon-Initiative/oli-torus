defmodule Oli.Rendering.Report.Html do
  @moduledoc """
  Implements the Html writer for content report rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error
  alias Oli.Delivery.Attempts.Core

  @behaviour Oli.Rendering.Report

  def report(
        %Context{enrollment: enrollment, user: user, mode: mode} = context,
        %{"id" => id, "activityId" => activity_id} = element
      ) do
        IO.inspect(mode)
    report =
      case mode do
        :author_preview ->
          render_author_preview(context)

        _ ->
          activity_attempt =
            Core.get_latest_activity_attempt(enrollment.section_id, user.id, activity_id)

          if is_nil(activity_attempt) do
            [
              "If you do not see your personalized report here, return and complete the activity linked to this report"
            ]
          else
            report_provider = report_provider(activity_attempt.revision.activity_type.slug)

            case Oli.Activities.Reports.Renderer.render(report_provider, context, element) do
              {:ok, report} -> report
              _ -> ["Unable to render report"]
            end
          end
      end

    [
      ~s|<div id="#{id}" class="activity-report"><div class="activity-report-label">Report</div><div class="content-purpose-content content">|,
      report,
      "</div></div>\n"
    ]
  end

  defp render_author_preview(%Context{} = context) do
    spec =
      VegaLite.from_json("""
      {
        "description": "A simple bar chart with embedded data.",
        "data": {
          "values": [
            {"a": "A", "b": 28}, {"a": "B", "b": 55}, {"a": "C", "b": 43},
            {"a": "D", "b": 91}, {"a": "E", "b": 81}, {"a": "F", "b": 53},
            {"a": "G", "b": 19}, {"a": "H", "b": 87}, {"a": "I", "b": 52}
          ]
        },
        "mark": "bar",
        "encoding": {
          "x": {"field": "a", "type": "nominal", "axis": {"labelAngle": 0}},
          "y": {"field": "b", "type": "quantitative"}
        }
      }

      """)
      |> VegaLite.to_spec()

    {:safe, attempt_selector} =
      OliWeb.Common.React.component(context, "Components.VegaLiteRenderer", %{spec: spec})

    [attempt_selector]
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end

  defp report_provider("oli_likert") do
    Module.concat([Oli, Activities, Reports, Providers, OliLikert])
  end
end
