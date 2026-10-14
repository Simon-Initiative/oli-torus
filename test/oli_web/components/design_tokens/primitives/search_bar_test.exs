defmodule OliWeb.Components.DesignTokens.Primitives.SearchBarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.DesignTokens.Primitives.SearchBar

  describe "search_bar/1" do
    test "renders a contextually labelled input and hides the decorative icon" do
      document =
        %{id: "course-search", aria_label: "Search courses", placeholder: "Find a course"}
        |> render_search_bar()
        |> Floki.parse_fragment!()

      assert [input] = Floki.find(document, "input#course-search")
      assert Floki.attribute(input, "aria-label") == ["Search courses"]
      assert Floki.attribute(input, "placeholder") == ["Find a course"]
      assert [icon] = Floki.find(document, "[aria-hidden='true'] svg")
      assert Enum.all?(["h-5", "w-5"], &(&1 in class_list(icon)))
      assert Floki.find(document, "button") == []
    end

    test "renders the clear control only for a non-empty value and clear action" do
      empty_html =
        render_search_bar(%{
          id: "empty-search",
          aria_label: "Search projects",
          value: "",
          on_clear: "clear_search"
        })

      refute empty_html =~ "empty-search-clear"

      document =
        %{
          id: "project-search",
          aria_label: "Search projects",
          value: "algebra",
          on_clear: "clear_search",
          clear_target: "#projects",
          clear_value_id: "project-search"
        }
        |> render_search_bar()
        |> Floki.parse_fragment!()

      assert [button] = Floki.find(document, "button#project-search-clear")
      assert Floki.attribute(button, "aria-label") == ["Clear search."]
      assert Floki.attribute(button, "phx-click") == ["clear_search"]
      assert Floki.attribute(button, "phx-target") == ["#projects"]
      assert Floki.attribute(button, "phx-value-id") == ["project-search"]
    end

    test "does not imply clear behavior when no clear action is supplied" do
      html =
        render_search_bar(%{
          id: "read-only-clear-contract",
          aria_label: "Search authors",
          value: "Ada"
        })

      refute html =~ "read-only-clear-contract-clear"
    end

    test "forwards LiveView and input attributes to the input" do
      document =
        %{
          id: "debounced-search",
          name: "query",
          aria_label: "Search questions",
          "phx-debounce": "300",
          autocomplete: "off"
        }
        |> render_search_bar()
        |> Floki.parse_fragment!()

      assert [input] = Floki.find(document, "input#debounced-search")
      assert Floki.attribute(input, "name") == ["query"]
      assert Floki.attribute(input, "phx-debounce") == ["300"]
      assert Floki.attribute(input, "autocomplete") == ["off"]
    end

    test "renders presentation mode without interactive controls" do
      document =
        %{
          id: "preview-search",
          aria_label: "Search preview",
          placeholder: "Search courses",
          interactive: false
        }
        |> render_search_bar()
        |> Floki.parse_fragment!()

      assert Floki.find(document, "input, button") == []
      assert Floki.find(document, "[aria-hidden='true']") != []
      assert document |> Floki.text() |> String.contains?("Search courses")
    end

    test "exposes the canonical catalog states" do
      for {state, expected_class} <- [
            {:default, "bg-Specially-Tokens-Fill-fill-input"},
            {:hover, "bg-Specially-Tokens-Fill-fill-input-focused"},
            {:focused, "shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"}
          ] do
        document =
          %{id: "#{state}-search", aria_label: "Search example", state: state}
          |> render_search_bar()
          |> Floki.parse_fragment!()

        assert [container] = Floki.find(document, "[data-search-bar-state='#{state}']")
        assert expected_class in class_list(container)
      end
    end

    test "keeps the focused treatment when the field is also hovered" do
      document =
        %{id: "combined-state-search", aria_label: "Search example"}
        |> render_search_bar()
        |> Floki.parse_fragment!()

      assert [container] = Floki.find(document, "[data-search-bar-state='default']")

      assert "hover:focus-within:bg-Specially-Tokens-Fill-fill-input" in class_list(container)

      assert "hover:focus-within:shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]" in class_list(
               container
             )
    end
  end

  defp render_search_bar(assigns) do
    render_component(&SearchBar.search_bar/1, assigns)
  end

  defp class_list(element) do
    element
    |> Floki.attribute("class")
    |> List.first("")
    |> String.split()
  end
end
