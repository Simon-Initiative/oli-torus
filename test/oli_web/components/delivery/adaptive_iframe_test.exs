defmodule OliWeb.Components.Delivery.AdaptiveIFrameTest do
  use ExUnit.Case, async: true

  alias Oli.Resources.Revision
  alias OliWeb.Components.Delivery.AdaptiveIFrame

  test "insights_preview/3 returns a centered iframe sized to the page screen with loading state" do
    page_revision = %Revision{
      slug: "adaptive-page",
      content: %{
        "custom" => %{"defaultScreenHeight" => 640, "defaultScreenWidth" => 960}
      }
    }

    revision = %Revision{slug: "second-screen", content: %{}}

    iframe = AdaptiveIFrame.insights_preview("adaptive_section", page_revision, revision)

    assert iframe =~ ~s(<div class="w-full overflow-x-auto p-4">)
    assert iframe =~ ~s(data-iframe-loading)
    assert iframe =~ "Loading screen preview..."
    assert iframe =~ "<iframe"
    assert iframe =~ ~s(width="992")
    assert iframe =~ ~s(height="672")

    assert iframe =~
             ~s(src="/sections/adaptive_section/preview/page/adaptive-page/adaptive_screen/second-screen")

    assert iframe =~ ~s(class="bg-white border-0 block mx-auto")
    assert iframe =~ ~s(loading="eager")
    assert iframe =~ ~s(onload=")
    assert iframe =~ "this.previousElementSibling?.remove();"
  end
end
