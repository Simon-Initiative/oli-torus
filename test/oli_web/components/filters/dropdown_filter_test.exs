defmodule OliWeb.Components.Filters.DropdownFilterTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Filters.DropdownFilter

  @options [
    %{id: 1, label: "Alvarez, Ana"},
    %{id: 2, label: "Bermudez, Bea"},
    %{id: 3, label: "Cruz, Cata"}
  ]

  defp doc(fun, assigns), do: fun |> render_component(assigns) |> Floki.parse_document!()

  describe "trigger/1" do
    test "names the panel it controls and says whether it is open" do
      closed = doc(&DropdownFilter.trigger/1, id: "student-filter", label: "Student", open: false)

      assert [button] = Floki.find(closed, "button#student-filter-trigger")
      assert Floki.attribute(button, "type") == ["button"]
      assert Floki.attribute(button, "aria-expanded") == ["false"]
      assert Floki.attribute(button, "aria-controls") == ["student-filter-panel"]
      assert Floki.text(button) =~ "Student"

      open = doc(&DropdownFilter.trigger/1, id: "student-filter", label: "Student", open: true)
      assert Floki.attribute(open, "button#student-filter-trigger", "aria-expanded") == ["true"]
    end

    test "counts the applied values, and says nothing about a count when none is applied" do
      none = doc(&DropdownFilter.trigger/1, id: "f", label: "Student", selected_count: 0)
      refute Floki.text(none) =~ "selected"
      assert Floki.attribute(none, "button#f-trigger", "data-active") == []

      two = doc(&DropdownFilter.trigger/1, id: "f", label: "Student", selected_count: 2)
      assert Floki.text(two) =~ ~r/Student\s*2\s*selected/
      assert Floki.attribute(two, "button#f-trigger", "data-active") == ["true"]
    end
  end

  describe "panel/1" do
    test "is hidden while closed and shown while open, under the id the trigger controls" do
      closed =
        doc(&DropdownFilter.panel/1,
          id: "f",
          open: false,
          inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "content" end}]
        )

      assert Floki.attribute(closed, "#f-panel", "hidden") != []

      open =
        doc(&DropdownFilter.panel/1,
          id: "f",
          open: true,
          inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "content" end}]
        )

      assert Floki.attribute(open, "#f-panel", "hidden") == []
      assert Floki.text(Floki.find(open, "#f-panel")) =~ "content"
    end
  end

  describe "search/1" do
    test "is a labelled text input named query that keeps what was typed" do
      search = doc(&DropdownFilter.search/1, id: "f", label: "Search students", value: "ana")

      assert [input] = Floki.find(search, "input#f-search")
      assert Floki.attribute(input, "name") == ["query"]
      assert Floki.attribute(input, "type") == ["text"]
      assert Floki.attribute(input, "value") == ["ana"]
      assert [label] = Floki.find(search, ~s(label[for="f-search"]))
      assert Floki.text(label) =~ "Search students"
    end
  end

  describe "checkbox_options/1" do
    test "one checkbox per option inside a fieldset named by its legend; checked values stay checked" do
      list =
        doc(&DropdownFilter.checkbox_options/1,
          id: "f",
          legend: "Student",
          options: @options,
          checked: [2]
        )

      assert Floki.text(Floki.find(list, "fieldset legend")) =~ "Student"

      boxes = Floki.find(list, ~s(fieldset input[type="checkbox"][name="selected[]"]))
      assert Enum.flat_map(boxes, &Floki.attribute(&1, "value")) == ["1", "2", "3"]

      assert Floki.attribute(list, ~s(input[value="2"]), "checked") != []
      assert Floki.attribute(list, ~s(input[value="1"]), "checked") == []
      assert Floki.text(list) =~ "Alvarez, Ana"
    end

    test "options outside the search are hidden, not removed, so a checked one stays in the form" do
      list =
        doc(&DropdownFilter.checkbox_options/1,
          id: "f",
          legend: "Student",
          options: @options,
          checked: [2],
          visible: [1]
        )

      assert length(Floki.find(list, ~s(input[type="checkbox"]))) == 3
      assert Floki.attribute(list, ~s(#f-option-1), "hidden") == []
      assert Floki.attribute(list, ~s(#f-option-2), "hidden") != []
      assert Floki.attribute(list, ~s(#f-option-3), "hidden") != []
      assert Floki.attribute(list, ~s(input[value="2"]), "checked") != []
    end

    test "announces how many options are shown, and says so when none matches" do
      some =
        doc(&DropdownFilter.checkbox_options/1,
          id: "f",
          legend: "Student",
          options: @options,
          checked: [],
          visible: [1, 3]
        )

      assert Floki.text(Floki.find(some, ~s([aria-live="polite"]))) =~ "2 options"
      refute Floki.text(some) =~ "No results found"

      none =
        doc(&DropdownFilter.checkbox_options/1,
          id: "f",
          legend: "Student",
          options: @options,
          checked: [],
          visible: []
        )

      assert Floki.text(none) =~ "No results found"
      assert Floki.text(Floki.find(none, ~s([aria-live="polite"]))) =~ "0 options"
    end
  end

  describe "actions/1" do
    test "Cancel does not submit the form; Apply does" do
      actions = doc(&DropdownFilter.actions/1, id: "f")

      assert Floki.attribute(actions, "button#f-cancel", "type") == ["button"]
      assert Floki.text(Floki.find(actions, "button#f-cancel")) =~ "Cancel"
      assert Floki.attribute(actions, "button#f-apply", "type") == ["submit"]
      assert Floki.text(Floki.find(actions, "button#f-apply")) =~ "Apply"
    end
  end
end
