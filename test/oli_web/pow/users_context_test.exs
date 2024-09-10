defmodule OliWeb.Pow.UserContextTest do
  use OliWeb.ConnCase

  alias OliWeb.Router.Helpers, as: Routes

  describe "users context" do
    setup [:setup_users]

    test "only queries independent learners for pow authentication", %{
      conn: conn,
      independent_user: independent_user
    } do
      # sign in independent user with same email address as existing lti user
      conn =
        recycle(conn)
        |> post(Routes.pow_session_path(conn, :create),
          user: %{email: independent_user.email, password: "password123"}
        )

      assert html_response(conn, 302) =~
               ~p"/workspaces/instructor"
    end
  end

  defp setup_users(_) do
    user =
      user_fixture(%{
        email: "same@example.edu",
        password: "password123",
        password_confirmation: "password123",
        independent_learner: false
      })

    independent_user =
      user_fixture(%{
        email: "same@example.edu",
        password: "password123",
        password_confirmation: "password123"
      })

    %{user: user, independent_user: independent_user}
  end
end
