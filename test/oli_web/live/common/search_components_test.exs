defmodule OliWeb.Common.SearchComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Common.{Filter, SearchInput, TextSearch}

  describe "SearchInput.render/1" do
    test "preserves its parent-form input contract while using SearchBar" do
      document =
        render_component(&SearchInput.render/1,
          id: "course-search",
          name: "course_name",
          text: "algebra",
          placeholder: "Search courses",
          aria_label: "Search courses"
        )
        |> Floki.parse_fragment!()

      assert Floki.find(document, "[data-search-bar-state='default']") != []
      assert [input] = Floki.find(document, "input#course-search-input")
      assert Floki.attribute(input, "name") == ["course_name"]
      assert Floki.attribute(input, "value") == ["algebra"]
      assert Floki.attribute(input, "placeholder") == ["Search courses"]
      assert Floki.attribute(input, "aria-label") == ["Search courses"]
      assert Floki.attribute(input, "phx-debounce") == ["300"]
    end
  end

  describe "Filter.render/1" do
    test "preserves change, blur, apply, and conditional reset events in the default variant" do
      document =
        render_component(&Filter.render/1,
          id: "publisher-search",
          change: "change_search",
          apply: "apply_search",
          reset: "reset_search",
          query: "open",
          debounce: "250",
          aria_label: "Search publishers"
        )
        |> Floki.parse_fragment!()

      assert [input] = Floki.find(document, "input#publisher-search-input")
      assert Floki.attribute(input, "phx-change") == ["change_search"]
      assert Floki.attribute(input, "phx-blur") == ["change_search"]
      assert Floki.attribute(input, "phx-debounce") == ["250"]
      assert Floki.attribute(input, "aria-label") == ["Search publishers"]

      assert [clear] = Floki.find(document, "button[aria-label='Clear search.']")
      assert Floki.attribute(clear, "id") == ["reset_search"]
      assert Floki.attribute(clear, "phx-click") == ["reset_search"]

      assert [apply] = Floki.find(document, "button[phx-click='apply_search']")
      assert apply |> Floki.text() |> String.trim() == "Search"
    end

    test "does not render a reset control for an empty query" do
      html =
        render_component(&Filter.render/1,
          change: "change_search",
          apply: "apply_search",
          reset: "reset_search",
          query: "",
          aria_label: "Search publishers"
        )

      refute html =~ "Clear search."
    end

    test "preserves the live-search form contract in the apply-icon variant" do
      document =
        render_component(&Filter.render/1,
          id: "source-search",
          change: "change_search",
          apply: "apply_search",
          reset: "reset_search",
          query: "biology",
          apply_icon: true,
          debounce: "300",
          aria_label: "Search course sources"
        )
        |> Floki.parse_fragment!()

      assert [form] = Floki.find(document, "form#source-search_form")
      assert Floki.attribute(form, "phx-change") == ["change_search"]
      assert Floki.attribute(form, "phx-submit") == ["change_search"]

      assert [input] = Floki.find(document, "input#source-search-input")
      assert Floki.attribute(input, "name") == ["value"]
      assert Floki.attribute(input, "phx-debounce") == ["300"]
      assert Floki.find(document, "button[aria-label='Clear search.']") != []
    end
  end

  describe "TextSearch.render/1" do
    test "preserves hook and target wiring and labels its conditional clear control" do
      document =
        render_component(&TextSearch.render/1,
          id: "project-search",
          text: "calculus",
          reset: "text_search_reset",
          change: "text_search_change",
          event_target: "#projects",
          aria_label: "Search projects",
          tooltip: "Search project titles"
        )
        |> Floki.parse_fragment!()

      assert [input] = Floki.find(document, "input#project-search-input")
      assert Floki.attribute(input, "phx-hook") == ["TextInputListener"]
      assert Floki.attribute(input, "phx-hook-target") == ["#projects"]
      assert Floki.attribute(input, "phx-target") == ["#projects"]
      assert Floki.attribute(input, "phx-value-change") == ["text_search_change"]
      assert Floki.attribute(input, "aria-label") == ["Search projects"]

      assert [clear] = Floki.find(document, "button[aria-label='Clear search.']")
      assert Floki.attribute(clear, "phx-click") == ["text_search_reset"]
      assert Floki.attribute(clear, "phx-target") == ["#projects"]
      assert Floki.attribute(clear, "phx-value-id") == ["project-search"]

      assert Floki.find(document, "[title='Search project titles']") != []
    end

    test "does not render a clear control for empty text" do
      html =
        render_component(&TextSearch.render/1,
          id: "empty-search",
          text: "",
          aria_label: "Search projects"
        )

      refute html =~ "Clear search."
    end
  end
end
