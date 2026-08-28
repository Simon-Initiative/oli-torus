defmodule OliWeb.Progress.ResourceTitleTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Numbering
  alias OliWeb.Progress.ResourceTitle

  describe "render/1" do
    test "renders numbered ancestor labels when no unit is suppressed (canonical numbering, display_numbering :not_set)" do
      node = %{
        revision: %{title: "Lesson 1"},
        ancestors: [
          unit(1, :not_set, "Unit 1"),
          module(1, :not_set, "Module 1")
        ]
      }

      html = render_component(&ResourceTitle.render/1, node: node, url: "/some/url")

      assert html =~ "Unit 1"
      assert html =~ "Module 1"
      assert html =~ "Lesson 1"
    end

    test "renders suppression-aware ancestor labels: numbered sibling renumbered, suppressed unit's own descendants fall back to bare titles" do
      renumbered_unit =
        unit(1, %Numbering{level: 1, index: 1}, "Unit 2")

      suppressed_unit =
        unit(2, nil, "Introduction")

      suppressed_module =
        module(1, nil, "Getting Started")

      html_for_renumbered_sibling =
        render_component(&ResourceTitle.render/1,
          node: %{revision: %{title: "Lesson 1"}, ancestors: [renumbered_unit]},
          url: "/some/url"
        )

      assert html_for_renumbered_sibling =~ "Unit 1"
      refute html_for_renumbered_sibling =~ "Unit 2"

      html_for_suppressed_subtree =
        render_component(&ResourceTitle.render/1,
          node: %{
            revision: %{title: "Lesson 1"},
            ancestors: [suppressed_unit, suppressed_module]
          },
          url: "/some/url"
        )

      assert html_for_suppressed_subtree =~ "Introduction"
      assert html_for_suppressed_subtree =~ "Getting Started"
      refute html_for_suppressed_subtree =~ "Unit 2"
      refute html_for_suppressed_subtree =~ "Module 1"
    end
  end

  defp unit(index, display_numbering, title) do
    %HierarchyNode{
      numbering: %Numbering{level: 1, index: index},
      display_numbering: display_numbering,
      revision: %{title: title}
    }
  end

  defp module(index, display_numbering, title) do
    %HierarchyNode{
      numbering: %Numbering{level: 2, index: index},
      display_numbering: display_numbering,
      revision: %{title: title}
    }
  end
end
