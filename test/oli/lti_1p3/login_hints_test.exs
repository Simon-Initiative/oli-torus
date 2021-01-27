defmodule Oli.Lti_1p3.LoginHintsTest do
  use Oli.DataCase

  alias Oli.Repo
  alias Oli.Lti_1p3.LoginHint
  alias Oli.Lti_1p3.LoginHints

  describe "lti 1.3 login_hints" do
    setup [:create_user]

    test "should get existing login_hint", %{user: user} do
      {:ok, login_hint} = %LoginHint{}
        |> LoginHint.changeset(%{value: "some-value", session_user_id: user.id})
        |> Repo.insert()

        fetched_login_hint = LoginHints.get_login_hint_by_value(login_hint.value)
      assert fetched_login_hint.value == "some-value"
      assert fetched_login_hint.session_user_id == user.id
    end

    test "should create new login_hint with specified user", %{user: user} do
      login_hint = LoginHints.create_login_hint!(user.id)

      assert login_hint.value != nil
      assert login_hint.session_user_id == user.id
    end

    test "should cleanup expired login_hints", %{user: user} do
      login_hint = LoginHints.create_login_hint!(user.id)

      # verify the login_hint exists before cleanup
      fetched_login_hint = LoginHints.get_login_hint_by_value(login_hint.value)
      assert fetched_login_hint == login_hint

      # fake the login_hint was created a day + 1 hour ago
      a_day_before = Timex.now |> Timex.subtract(Timex.Duration.from_hours(25))
      login_hint
      |> Ecto.Changeset.cast(%{inserted_at: a_day_before}, [:inserted_at])
      |> Repo.update!

      # cleanup
      LoginHints.cleanup_login_hint_store()

      fetched_login_hint = LoginHints.get_login_hint_by_value(login_hint.value)
      assert fetched_login_hint == nil
    end
  end

  defp create_user(conn) do
    user = user_fixture()

    %{conn: conn, user: user}
  end

end
