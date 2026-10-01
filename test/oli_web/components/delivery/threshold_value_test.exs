defmodule OliWeb.Components.Delivery.ThresholdValueTest do
  use OliWeb.ConnCase, async: true
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.ThresholdValue

  test "renders an accessible warning that inherits the current text color" do
    html = render_threshold(true)

    assert html =~ ~s(role="img")
    assert html =~ ~s(aria-label="Average score below threshold")
    assert html =~ ~s(aria-hidden="true")
    assert html =~ "stroke-current"
    assert html =~ "25%"
  end

  test "keeps the value layout stable without rendering a warning when it is not at risk" do
    html = render_threshold(false)

    assert html =~ "inline-flex items-center gap-1 whitespace-nowrap"
    assert html =~ "25%"
    refute html =~ ~s(role="img")
    refute html =~ "stroke-current"
  end

  defp render_threshold(at_risk) do
    render_component(
      fn assigns ->
        ~H"""
        <div class="text-Text-text-danger">
          <ThresholdValue.render
            at_risk={@at_risk}
            warning_label="Average score below threshold"
          >
            25%
          </ThresholdValue.render>
        </div>
        """
      end,
      %{at_risk: at_risk}
    )
  end
end
