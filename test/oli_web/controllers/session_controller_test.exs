defmodule OliWeb.SessionControllerTest do
  use OliWeb.ConnCase
  alias Oli.{Repo, User}

  @ueberauth_auth %{
    credentials: %{token: "fdsnoafhnoofh08h38h"},
    info: %{email: "ironman@example.com", first_name: "Tony", last_name: "Stark"},
    provider: :google
  }

  test "redirects user to Google for authentication", %{conn: conn} do
    conn = get conn, "auth/google?scope=email%20profile"
    assert redirected_to(conn, 302)
  end

  test "creates user from Google information", %{conn: conn} do
    conn = conn
    |> assign(:ueberauth_auth, @ueberauth_auth)
    |> get("/auth/google/callback")

    users = User |> Repo.all
    assert Enum.count(users) == 1
    assert get_flash(conn, :info) == "Thank you for signing in!"
  end
end
