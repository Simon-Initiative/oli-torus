defmodule OliWeb.AuthControllerTest do
  use OliWeb.ConnCase

  test "redirects author to Google for authentication", %{conn: conn} do
    conn = get conn, "auth/google?scope=email%20profile"
    assert redirected_to(conn, 302)
  end

  test "signs out author", %{conn: conn} do
    author = author_fixture()

    conn =
      conn
      |> assign(:current_author, author)
      |> get("/auth/signout")
      |> get("/")

    assert conn.assigns["current_author"] == nil
  end

  describe "log in" do
    test "redirects to workspace if author has multiple projects"
    test "redirects to project overview if author only has one project"
  end
end
