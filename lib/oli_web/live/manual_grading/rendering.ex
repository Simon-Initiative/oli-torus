defmodule OliWeb.ManualGrading.Rendering do

  alias Oli.Delivery.Sections.Section
  alias Oli.Rendering.Context
  alias Oli.Rendering.Activity.Html

  require Logger

  def create_rendering_context(attempt, part_attempts, activity_types_map, %Section{slug: section_slug}) do

    part_attempts_map = Enum.reduce(part_attempts, %{}, fn pa, m -> Map.put(m, pa.part_id, pa) end)
    attempt_parts = Map.put(%{}, attempt.resource_id, {attempt, part_attempts_map})
    resource_attempt = Oli.Delivery.Attempts.Core.get_resource_attempt(attempt_guid: attempt.resource_attempt_guid)

    %Context{
      user: attempt.user,
      section_slug: section_slug,
      revision_slug: attempt.revision.slug,
      page_id: attempt.page_id,
      mode: :review,
      activity_map: Oli.Delivery.Page.ActivityContext.create_context_map(attempt.graded, attempt_parts, prune: false),
      activity_types_map: activity_types_map,
      resource_attempt: resource_attempt
    }

  end

  def render(%Context{} = context, mode) do
    # Html.activity(%{context | mode: mode}, %{"purpose" => "none", "activity_id" => Map.keys(context.activity_map) |> hd})
    activity_id = Map.keys(context.activity_map) |> hd
    activity_summary = context.activity_map[activity_id]

    case activity_summary.delivery_element do
      "oli-adaptive-delivery" ->
        # somewhere around here or before here I need to get the sequenceId from the page and map it to the activity model
        case mode do
          :instructor_preview ->
            ["<div>link to instructor preview</div>"]
          _ ->
            # ["<pre>#{context.page_id}</pre>"]
            Html.activity(%{context | mode: mode}, %{"purpose" => "none", "activity_id" => activity_id})
        end

      _ ->
        Html.activity(%{context | mode: mode}, %{"purpose" => "none", "activity_id" => activity_id})
    end

  end

end
