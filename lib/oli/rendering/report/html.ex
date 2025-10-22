defmodule Oli.Rendering.Report.Html do
  @moduledoc """
  Implements the Html writer for content report rendering
  """
  alias Oli.Rendering.Context
  alias Oli.Rendering.Error
  alias Oli.Activities.Reports.ProviderList

  require Logger

  @behaviour Oli.Rendering.Report

  def report(
        %Context{mode: mode} =
          context,
        %{"id" => id, "activityId" => activity_id} = element
      ) do
    report =
      case mode do
        :author_preview ->
          render_author_preview(context)

        _ ->
          case Oli.Resources.get_activity_registration_by_resource_id(activity_id) do
            nil ->
              Logger.error(
                "Error rendering activity report: #{inspect(%{section_slug: context.section_slug, user_id: context.user.id, activity_id: activity_id})}"
              )

              [~s|<div class="alert alert-danger">Activity report render error</div>|]

            registration ->
              render_with_provider(registration.slug, context, element)
          end
      end

    [
      ~s|<div id="#{id}" class="activity-report"><div class="activity-report-label">Report</div><div class="content-purpose-content content">|,
      report,
      "</div></div>\n"
    ]
  end

  defp render_with_provider(slug, context, %{"activityId" => activity_id} = element) do
    report_provider =
      ProviderList.report_provider(slug)

    case Oli.Activities.Reports.Renderer.render(report_provider, context, element) do
      {:ok, report} ->
        [report]

      e ->
        Logger.error(
          "Error rendering activity report: #{inspect(%{error: e, section_slug: context.section_slug, user_id: context.user.id, activity_id: activity_id})}"
        )

        [~s|<div class="alert alert-danger">Activity report render error</div>|]
    end
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
      OliWeb.Common.React.component(context, "Components.VegaLiteRenderer", %{spec: spec},
        id: "vega-#{UUID.uuid4()}"
      )

    [attempt_selector]
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
