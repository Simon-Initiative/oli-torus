defmodule OliWeb.Components.Delivery.ScheduleGatingAssessmentTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.ScheduleGatingAssessment

  describe "tabs/1" do
    test "does not show advanced gating for product settings" do
      html =
        render_component(&ScheduleGatingAssessment.tabs/1, %{
          section_slug: "product-slug",
          uri: "/authoring/products/product-slug/assessment_settings/settings/all",
          product_path_base: "/authoring/products/product-slug"
        })

      assert html =~ "Schedule"
      assert html =~ "Assessment Settings"
      refute html =~ "Advanced Gating"
      refute html =~ "/authoring/products/product-slug/gating_and_scheduling"
    end

    test "shows advanced gating for section settings" do
      html =
        render_component(&ScheduleGatingAssessment.tabs/1, %{
          section_slug: "section-slug",
          uri: "/sections/section-slug/schedule"
        })

      assert html =~ "Advanced Gating"
      assert html =~ "/sections/section-slug/gating_and_scheduling"
    end
  end
end
