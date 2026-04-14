defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.SummaryTileTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.SummaryTile

  test "renders recommendation message when recommendation payload is present" do
    html =
      render_component(&SummaryTile.tile/1, %{
        status: "Showing latest recommendation",
        recommendation: %{
          id: 10,
          state: :ready,
          message:
            "Inference: Assessment performance in Quiz 1 is lagging behind progress through the scoped content; review Quiz 1 and reinforce the related concepts."
        }
      })

    assert html =~ "Showing latest recommendation"
    assert html =~ "AI Recommendation"
    assert html =~ "Assessment performance in Quiz 1 is lagging behind progress"
    refute html =~ "Scoped metrics and AI recommendation placeholders."
  end

  test "renders placeholder state while recommendation is not yet available" do
    html =
      render_component(&SummaryTile.tile/1, %{
        status: "Loading recommendation",
        recommendation: nil
      })

    assert html =~ "Loading recommendation"
    assert html =~ "Scoped metrics and AI recommendation placeholders."
  end

  test "renders regenerate button" do
    html =
      render_component(&SummaryTile.tile/1, %{
        status: "Showing latest recommendation",
        recommendation: %{message: "Review the latest module."}
      })

    assert html =~ "Regenerate"
    assert html =~ "summary_recommendation_regenerate"
  end

  test "disables regenerate button while recommendation is busy" do
    html =
      render_component(&SummaryTile.tile/1, %{
        status: "Generating recommendation",
        recommendation: %{state: :generating, message: nil},
        summary_recommendation_inflight: true
      })

    assert html =~ "disabled"
    assert html =~ "cursor-not-allowed"
    assert html =~ "opacity-50"
  end
end
