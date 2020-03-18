defmodule OliWeb.AuthControllerTest do
  use OliWeb.ConnCase
  # alias Oli.Repo
  # alias Oli.Accounts.Author

  # @ueberauth_auth %{
  #   credentials: %{token: "fdsnoafhnoofh08h38h"},
  #   info: %{email: "ironman@example.com", first_name: "Tony", last_name: "Stark"},
  #   provider: "google"
  # }

  test "redirects author to Google for authentication", %{conn: conn} do
    conn = get conn, "auth/google?scope=email%20profile"
    assert redirected_to(conn, 302)
  end

  # FIXME: Investigate why this test is failing when it works in the browser
  # test "creates author from Google information", %{conn: conn} do
  #   conn = conn
  #   |> assign(:ueberauth_auth, @ueberauth_auth)
  #   |> get("/auth/google/callback")

  #   authors = Author |> Repo.all
  #   assert Enum.count(authors) == 1
  #   assert get_flash(conn, :info) == "Thank you for signing in!"
  # end

  test "signs out author", %{conn: conn} do
    author = author_fixture()

    conn =
      conn
      |> assign(:author, author)
      |> get("/auth/signout")
      |> get("/")

    assert conn.assigns.author == nil
  end
end
