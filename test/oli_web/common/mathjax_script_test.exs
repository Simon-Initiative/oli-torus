defmodule OliWeb.Common.MathJaxScriptTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Common.MathJaxScript

  test "enables the MathJax accessibility explorer by default" do
    html = render_component(&MathJaxScript.render/1, %{})

    assert html =~ "menuOptions"
    assert html =~ "explorer: true"
  end
end
