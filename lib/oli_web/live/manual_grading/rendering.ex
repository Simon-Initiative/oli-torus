defmodule OliWeb.ManualGrading.Rendering do

  alias Oli.Delivery.Sections.Section
  alias Oli.Rendering.Context
  alias Oli.Rendering.Activity.Html

  def create_rendering_context(attempt, part_attempts, activity_types_map, %Section{slug: section_slug}) do

    part_attempts_map = Enum.reduce(part_attempts, %{}, fn pa, m -> Map.put(m, pa.part_id, pa) end)
    attempt_parts = Map.put(%{}, attempt.resource_id, {attempt, part_attempts_map})

    %Context{
      user: attempt.user,
      section_slug: section_slug,
      revision_slug: attempt.revision.slug,
      mode: :review,
      activity_map: Oli.Delivery.Page.ActivityContext.create_context_map(attempt.graded, attempt_parts, prune: false),
      activity_types_map: activity_types_map
    }

  end

  def render(%Context{} = context, mode) do
    Html.activity(%{context | mode: mode}, %{"purpose" => "none", "activity_id" => Map.keys(context.activity_map) |> hd})
  end

end
