defmodule Oli.Content.Group.HtmlTest do
  use ExUnit.Case, async: true

  alias Oli.Rendering.Context
  alias Oli.Rendering.Group.Html

  describe "html group renderer" do
    test "renders purpose none with purpose wrapper" do
      rendered_html =
        Html.group(%Context{}, fn -> "<p>inner content</p>" end, %{
          "id" => "group-1",
          "purpose" => "none"
        })

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~ ~s|<div id="group-1" class="group content-purpose none">|

      assert rendered_html_string =~
               ~s|<div class="content-purpose-content content"><p>inner content</p></div>|
    end

    test "renders purposeful groups with purpose wrapper" do
      rendered_html =
        Html.group(%Context{}, fn -> "<p>inner content</p>" end, %{
          "id" => "group-2",
          "purpose" => "learnbydoing"
        })

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~
               ~s|<div id="group-2" class="group content-purpose learnbydoing">|

      assert rendered_html_string =~
               ~s|<div class="flex content-purpose-label"><div class="flex-grow-1">Learn by doing</div><div></div></div>|

      assert rendered_html_string =~
               ~s|<div class="content-purpose-content content"><p>inner content</p></div>|
    end

    test "marks none groups containing activities" do
      rendered_html =
        Html.group(%Context{}, fn -> "<p>inner content</p>" end, %{
          "id" => "group-3",
          "purpose" => "none",
          "children" => [%{"type" => "activity-reference", "activity_id" => 1}]
        })

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~
               ~s|<div id="group-3" class="group content-purpose none has-activity-reference">|
    end
  end
end
