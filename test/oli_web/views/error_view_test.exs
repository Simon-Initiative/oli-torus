defmodule OliWeb.ErrorViewTest do
  use OliWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 404.html" do
    assert render_to_string(OliWeb.ErrorView, "404.html", reason: %{plug_status: 404}) =~
             "404 Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(OliWeb.ErrorView, "500.html", reason: %{plug_status: 500}) =~
             "500 Internal Server Error"
  end

  test "renders 403.html" do
    assert render_to_string(OliWeb.ErrorView, "403.html", reason: %{plug_status: 403}) =~
             "403 Forbidden"
  end
end
