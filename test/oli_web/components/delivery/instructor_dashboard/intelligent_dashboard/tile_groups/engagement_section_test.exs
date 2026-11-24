defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.EngagementSectionTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.EngagementSection

  test "names its move handle after the Engagement card" do
    [handle] =
      render_component(&EngagementSection.section/1,
        section_slug: "demo-section",
        section_id: 1,
        expanded: false
      )
      |> Floki.parse_document!()
      |> Floki.find("#learning-dashboard-engagement-group-move")

    assert Floki.attribute(handle, "aria-label") == ["Move Engagement card"]
    assert Floki.attribute(handle, "title") == ["Move Engagement card"]
  end
end
