defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.ContentSectionTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.ContentSection

  test "names its move handle after the Content card" do
    [handle] =
      render_component(&ContentSection.section/1, section_slug: "demo-section", expanded: false)
      |> Floki.parse_document!()
      |> Floki.find("#learning-dashboard-content-group-move")

    assert Floki.attribute(handle, "aria-label") == ["Move Content card"]
    assert Floki.attribute(handle, "title") == ["Move Content card"]
  end
end
