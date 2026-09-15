defmodule OliWeb.Delivery.Content.MultiSelectTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Delivery.Content.MultiSelect

  test "defaults to the toggle_selected phx-change event" do
    html =
      render_component(&MultiSelect.render/1,
        id: "proficiency_select",
        options: [%{id: 1, name: "Low", selected: false}],
        selected_values: %{},
        selected_ids: [],
        target: %{}
      )

    assert html =~ ~s(phx-change="toggle_selected")
  end

  test "uses a distinct toggle_event so two selects on the same page do not collide" do
    html =
      render_component(&MultiSelect.render/1,
        id: "confidence_select",
        options: [%{id: 1, name: "Low", selected: false}],
        selected_values: %{},
        selected_ids: [],
        target: %{},
        toggle_event: "toggle_confidence_selected",
        submit_event: "apply_confidence_filter"
      )

    assert html =~ ~s(phx-change="toggle_confidence_selected")
    refute html =~ ~s(phx-change="toggle_selected")
  end
end
