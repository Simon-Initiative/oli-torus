defmodule Oli.Rendering.Report.Html do
  @moduledoc """
  Implements the Html writer for content report rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error
  alias Oli.Delivery.Attempts.Core
  alias Oli.Activities.Reports.ProviderList
  alias Oli.Publishing.DeliveryResolver

  require Logger

  @behaviour Oli.Rendering.Report

  def report(
        %Context{enrollment: enrollment, user: user, mode: mode, section_slug: section_slug} =
          context,
        %{"id" => id, "activityId" => activity_id} = element
      ) do
    report =
      case mode do
        :author_preview ->
          render_author_preview(context)

        _ ->
          parent_link =
            case determine_parent_page(section_slug, activity_id) do
              %{id: _id, slug: slug} ->
                parent_revision = DeliveryResolver.from_revision_slug(section_slug, slug)

                [
                  ~s|<div class="container"><h3 class="text-center"><a href=#{"/sections/#{section_slug}/lesson/#{slug}"} target="_blank">#{parent_revision.title}</a></h3></div>|
                ]

              _ ->
                ["<div></div>"]
            end

          activity_attempt =
            Core.get_latest_activity_attempt(enrollment.section_id, user.id, activity_id)

          if is_nil(activity_attempt) do
            [
              ~s|<div>If you do not see your personalized report here, it means that you have not yet completed the activity linked to this report</div>|
            ]
          else
            report_provider =
              ProviderList.report_provider(activity_attempt.revision.activity_type.slug)

            case Oli.Activities.Reports.Renderer.render(report_provider, context, element) do
              {:ok, report} ->
                [parent_link, report]

              e ->
                Logger.error(
                  "Error rendering activity report: #{inspect(%{error: e, section_slug: context.section_slug, user_id: context.user.id, activity_id: activity_id})}"
                )

                [~s|<div class="alert alert-danger">Activity report render error</div>|]
            end
          end
      end

    [
      ~s|<div id="#{id}" class="activity-report"><div class="activity-report-label">Report</div><div class="content-purpose-content content">|,
      report,
      "</div></div>\n"
    ]
  end

  defp determine_parent_page(section_slug, activity_id) do
    pub_ids = DeliveryResolver.section_publication_ids(section_slug) |> Oli.Repo.all()

    Enum.reduce(pub_ids, %{}, fn a, c ->
      case Map.get(Oli.Publishing.determine_parent_pages([activity_id], a), activity_id) do
        nil -> c
        p -> p
      end
    end)
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
end
