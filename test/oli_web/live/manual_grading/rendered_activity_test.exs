defmodule OliWeb.ManualGrading.RenderedActivityTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.ManualGrading.RenderedActivity

  @activity ~s(<div id="jump-question-5"><div id="adaptive-screen-preview-a-b"></div></div>)

  defp ids(html),
    do: html |> Floki.parse_fragment!() |> Floki.attribute("[id]", "id")

  test "prefixes the activity's own ids with the component id, as a string or as iodata" do
    for rendered <- [
          @activity,
          [~s(<div id="jump-question-5">), ~s(<div id="adaptive-screen-preview-a-b"></div></div>)]
        ] do
      html =
        render_component(&RenderedActivity.render/1, %{id: "copy", rendered_activity: rendered})

      assert ids(html) == ["copy", "copy-jump-question-5", "copy-adaptive-screen-preview-a-b"]
    end
  end

  test "leaves the activity's ids alone without a component id" do
    html = render_component(&RenderedActivity.render/1, %{rendered_activity: @activity})

    assert ids(html) == ["jump-question-5", "adaptive-screen-preview-a-b"]
  end
end
