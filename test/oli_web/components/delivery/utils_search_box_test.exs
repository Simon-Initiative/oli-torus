defmodule OliWeb.Components.Delivery.UtilsSearchBoxTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.Utils

  describe "search_box/1" do
    test "preserves delivery search events while using the shared Search Bar" do
      document =
        render_component(&Utils.search_box/1,
          id: "lesson-search",
          search_term: "limits",
          aria_label: "Search lesson notes",
          placeholder: "Search notes",
          on_search: "search_notes",
          on_change: "search_notes",
          on_clear_search: "clear_notes"
        )
        |> Floki.parse_fragment!()

      assert [form] = Floki.find(document, "form")
      assert Floki.attribute(form, "phx-submit") == ["search_notes"]
      assert Floki.attribute(form, "phx-change") == ["search_notes"]

      assert [input] = Floki.find(document, "input#lesson-search")
      assert Floki.attribute(input, "name") == ["search_term"]
      assert Floki.attribute(input, "value") == ["limits"]
      assert Floki.attribute(input, "placeholder") == ["Search notes"]
      assert Floki.attribute(input, "aria-label") == ["Search lesson notes"]
      assert Floki.attribute(input, "phx-debounce") == ["500"]

      assert [clear] = Floki.find(document, "button[aria-label='Clear search.']")
      assert Floki.attribute(clear, "phx-click") == ["clear_notes"]
    end

    test "does not render a clear control for an empty search term" do
      html = render_component(&Utils.search_box/1, id: "empty-delivery-search")

      refute html =~ "Clear search."
    end
  end
end
