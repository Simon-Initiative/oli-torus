defmodule OliWeb.ManualGrading.Rendering do
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Rendering.Context
  alias Oli.Rendering.Activity.Html
  alias OliWeb.Components.Delivery.AdaptiveIFrame

  def create_rendering_context(attempt, part_attempts, activity_types_map, %Section{
        slug: section_slug
      }) do
    part_attempts_map =
      Enum.reduce(part_attempts, %{}, fn pa, m -> Map.put(m, pa.part_id, pa) end)

    attempt_parts = Map.put(%{}, attempt.resource_id, {attempt, part_attempts_map})

    resource_attempt =
      Core.get_resource_attempt(attempt_guid: attempt.resource_attempt_guid)

    effective_settings = Oli.Delivery.Settings.get_combined_settings(resource_attempt)

    content_for_ordinal_assignment =
      case resource_attempt.content do
        nil -> resource_attempt.revision.content
        content -> content
      end

    extrinsic_state = Core.fetch_extrinsic_state(resource_attempt)

    %Context{
      user: attempt.user,
      section_slug: section_slug,
      revision_slug: attempt.revision.slug,
      activity_revision_id: attempt.revision_id,
      page_id: attempt.page_id,
      mode: :review,
      activity_map:
        Oli.Delivery.Page.ActivityContext.create_context_map(
          attempt.graded,
          attempt_parts,
          nil,
          nil,
          effective_settings,
          prune: false,
          assign_ordinals_from: content_for_ordinal_assignment
        ),
      activity_types_map: activity_types_map,
      resource_attempt: resource_attempt,
      extrinsic_state: extrinsic_state
    }
  end

  def render(%Context{} = context, mode) do
    activity_id = context.activity_map |> Map.keys() |> hd
    activity_summary = context.activity_map[activity_id]

    with "oli-adaptive-delivery" <- activity_summary.delivery_element,
         :instructor_preview <- mode,
         %{content: %{"advancedDelivery" => true}} = page_revision <-
           DeliveryResolver.from_resource_id(context.section_slug, context.page_id),
         screen_revision <-
           DeliveryResolver.from_resource_id(context.section_slug, activity_id) do
      AdaptiveIFrame.screen_preview(
        context.section_slug,
        page_revision,
        screen_revision,
        attempt_guid: context.resource_attempt.attempt_guid,
        page_revision_id: context.resource_attempt.revision_id,
        screen_revision_id: context.activity_revision_id
      )
    else
      _ ->
        Html.activity(%{context | mode: mode}, %{
          "purpose" => "none",
          "activity_id" => activity_id
        })
    end
  end
end
