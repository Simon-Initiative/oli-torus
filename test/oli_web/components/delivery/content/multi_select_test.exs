defmodule OliWeb.Delivery.Content.MultiSelectTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Delivery.Content.MultiSelect
  alias OliWeb.Delivery.Content.PercentageSelector
  alias OliWeb.Delivery.Content.SelectDropdown

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

  test "renders an accessible keyboard trigger and controlled panel" do
    html =
      render_component(&MultiSelect.render/1,
        id: "proficiency_select",
        options: [%{id: 1, name: "Low", selected: false}],
        selected_values: %{},
        selected_ids: [],
        target: %{}
      )

    assert html =~ ~s(data-filter-trigger)
    assert html =~ ~s(aria-label="Proficiency")
    assert html =~ ~s(aria-expanded="false")
    assert html =~ ~s(aria-controls="proficiency_select-options-container")
    assert html =~ ~s(data-filter-panel)
    assert html =~ ~s(phx-hook="AccessibleFilterDropdown")
  end

  test "shared filter controls expose the same trigger contract" do
    dropdown =
      render_component(&SelectDropdown.render/1,
        id: "enrolled",
        name: "enrolled",
        phx_change: "change_enrollment",
        options: [%{label: "All", value: "all"}]
      )

    progress =
      render_component(&PercentageSelector.render/1,
        id: "progress",
        percentage: nil,
        selector: :is_equal_to,
        target: %{}
      )

    for html <- [dropdown, progress] do
      assert html =~ ~s(data-filter-trigger)
      assert html =~ ~s(aria-expanded="false")
      assert html =~ ~s(data-filter-panel)
      assert html =~ ~s(phx-hook="AccessibleFilterDropdown")
    end
  end
end
