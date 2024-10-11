defmodule OliWeb.ManualGrading.Rendering do
  alias Oli.Delivery.Sections.Section
  alias Oli.Rendering.Context
  alias Oli.Rendering.Activity.Html
  alias OliWeb.Router.Helpers, as: Routes

  def create_rendering_context(attempt, part_attempts, activity_types_map, %Section{
        slug: section_slug
      }) do
    part_attempts_map =
      Enum.reduce(part_attempts, %{}, fn pa, m -> Map.put(m, pa.part_id, pa) end)

    attempt_parts = Map.put(%{}, attempt.resource_id, {attempt, part_attempts_map})

    resource_attempt =
      Oli.Delivery.Attempts.Core.get_resource_attempt(attempt_guid: attempt.resource_attempt_guid)

    effective_settings = Oli.Delivery.Settings.get_combined_settings(resource_attempt)

    %Context{
      user: attempt.user,
      section_slug: section_slug,
      revision_slug: attempt.revision.slug,
      page_id: attempt.page_id,
      mode: :review,
      activity_map:
        Oli.Delivery.Page.ActivityContext.create_context_map(
          attempt.graded,
          attempt_parts,
          nil,
          nil,
          effective_settings,
          prune: false
        ),
      activity_types_map: activity_types_map,
      resource_attempt: resource_attempt
    }
  end

  def render(%Context{} = context, mode) do
    activity_id = context.activity_map |> Map.keys() |> hd
    activity_summary = context.activity_map[activity_id]

    with "oli-adaptive-delivery" <- activity_summary.delivery_element,
         :instructor_preview <- mode do
      preview_url =
        Routes.page_delivery_path(
          OliWeb.Endpoint,
          :page_preview,
          context.section_slug,
          context.revision_slug
        )

      [
        "<button target=_blank href=#{preview_url} class=\"btn btn-outline-primary mr-2\" disabled>Preview Course Content</button><span class=\"badge badge-info\">Coming Soon</span>"
      ]
    else
      _ ->
        Html.activity(%{context | mode: mode}, %{
          "purpose" => "none",
          "activity_id" => activity_id
        })
    end
  end
end
