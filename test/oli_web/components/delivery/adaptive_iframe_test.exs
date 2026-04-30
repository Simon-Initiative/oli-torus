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

    assert iframe =~ ~s(<div class="w-full overflow-x-auto p-4" phx-hook="IframeLoadState">)
    assert iframe =~ ~s(data-iframe-loading)
    assert iframe =~ "Loading screen preview..."
    assert iframe =~ "<iframe"
    assert iframe =~ ~s(width="992")
    assert iframe =~ ~s(height="672")

    assert iframe =~
             ~s(src="/sections/adaptive_section/preview/page/adaptive-page/adaptive_screen/second-screen")

    assert iframe =~ ~s(class="bg-white border-0 block mx-auto")
    assert iframe =~ ~s(loading="eager")
    refute iframe =~ ~s(onload=")
  end

  test "screen_preview/4 includes explicit revision ids for attempt-bound previews" do
    page_revision = %Revision{
      slug: "adaptive-page",
      content: %{
        "custom" => %{"defaultScreenHeight" => 640, "defaultScreenWidth" => 960}
      }
    }

    revision = %Revision{slug: "second-screen", content: %{}}

    iframe =
      AdaptiveIFrame.screen_preview("adaptive_section", page_revision, revision,
        attempt_guid: "attempt-1",
        page_revision_id: 101,
        screen_revision_id: 202
      )

    assert iframe =~ "attempt_guid=attempt-1"
    assert iframe =~ "page_revision_id=101"
    assert iframe =~ "screen_revision_id=202"
  end

  test "preview/3 carries preview_sequence_id for author preview iframe routes" do
    revision = %Revision{
      slug: "adaptive-page",
      content: %{
        "custom" => %{"defaultScreenHeight" => 640, "defaultScreenWidth" => 960}
      }
    }

    iframe =
      AdaptiveIFrame.preview("authoring_project", revision,
        preview_sequence_id: "screen_sequence_123"
      )

    assert iframe =~
             ~s(src="/authoring/project/authoring_project/preview_fullscreen/adaptive-page?preview_sequence_id=screen_sequence_123")
  end
end
