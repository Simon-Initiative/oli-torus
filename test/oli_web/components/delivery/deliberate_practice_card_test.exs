defmodule OliWeb.Components.Delivery.DeliberatePracticeCardTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.DeliberatePractice

  describe "practice_card/1" do
    test "uses the new preview lesson route in preview mode" do
      assigns = %{
        dark: false,
        practice: %{
          title: "Practice Title",
          slug: "practice-title",
          intro_content: nil,
          poster_image: nil
        },
        section_slug: "test-section",
        preview_mode: true
      }

      html = render_component(&DeliberatePractice.practice_card/1, assigns)

      assert html =~ "/sections/test-section/preview/lesson/practice-title"
      assert html =~ "request_path=%2Fsections%2Ftest-section%2Fpreview%2Fpractice"
    end
  end
end
