defmodule Oli.Accounts.AuditedSessionsTest do
  use OliWeb.ConnCase, async: true

  import Ecto.Query
  import Oli.Factory

  alias Ecto.Multi
  alias Oli.Accounts
  alias Oli.Accounts.{Audited, UserToken}
  alias Oli.Auditing.{Context, LogEvent}
  alias Oli.Repo
  alias OliWeb.{AuthorAuth, UserAuth}

  describe "issue_session/4" do
    test "records the login with its method and token row, never the token" do
      user = insert(:user)

      {:ok, %{token: token, token_id: token_id}} =
        Audited.issue_session(Context.for_actor(user, source: :ui), user, :password)

      assert Repo.get!(UserToken, token_id).token == token
      assert [event] = events(:user_logged_in)
      assert event.user_id == user.id
      assert event.affected_user_id == user.id
      assert event.event_key == "session:#{token_id}:issued"
      assert event.details == %{"auth_method" => "password", "session_ref" => token_id}
      refute event |> Map.take([:changes, :details, :search_text]) |> inspect() =~ inspect(token)
    end

    test "a secure assessment session is scoped to its section" do
      user = insert(:user)
      section = insert(:section)
      resource = insert(:resource)

      scope = %Oli.Delivery.SecureAssessments.Scope{
        section_id: section.id,
        resource_id: resource.id
      }

      {:ok, %{token: token}} =
        Multi.new()
        |> Audited.issue_session_multi(:session, Context.for_actor(user, source: :ui), {
          user,
          :lti,
          [scope: scope]
        })
        |> Repo.transaction()
        |> then(fn {:ok, %{session: session}} -> {:ok, session} end)

      assert Repo.get_by!(UserToken, token: token).secure_section_id == section.id
      assert [event] = events(:user_logged_in)
      assert event.section_id == section.id
      assert event.details["auth_method"] == "lti"
    end

    test "only the account itself can be issued a session" do
      user = insert(:user)
      other = Context.for_actor(insert(:author), source: :ui)

      assert {:error, :invalid_request} = Audited.issue_session(other, user, :password)
      assert events(:user_logged_in) == []
    end

    test "a failure later in the caller's transaction rolls back the token and the event" do
      user = insert(:user)

      assert {:error, :later, :failed, _changes} =
               Multi.new()
               |> Audited.issue_session_multi(:session, Context.for_actor(user, source: :ui), {
                 user,
                 :lti,
                 []
               })
               |> Multi.run(:later, fn _repo, _changes -> {:error, :failed} end)
               |> Repo.transaction()

      refute Repo.get_by(UserToken, user_id: user.id, context: "session")
      assert events(:user_logged_in) == []
    end
  end

  describe "revoke_session/2" do
    test "records one logout even when the same token is revoked again" do
      user = insert(:user)

      {:ok, %{token: token, token_id: token_id}} =
        Audited.issue_session(Context.for_actor(user, source: :ui), user, :password)

      assert {:ok, :revoked} = Audited.revoke_session(:user, token)
      assert {:ok, :absent} = Audited.revoke_session(:user, token)

      assert [event] = events(:user_logged_out)
      assert event.user_id == user.id
      assert event.event_key == "session:#{token_id}:revoked"
    end

    test "a sign-out still revokes the token when its event cannot be written" do
      user = insert(:user)

      {:ok, %{token: token, token_id: token_id}} =
        Audited.issue_session(Context.for_actor(user, source: :ui), user, :password)

      Repo.query!("""
      CREATE FUNCTION pg_temp.reject_logout_event() RETURNS trigger AS $$
      BEGIN
        IF NEW.event_type = 'user_logged_out' THEN
          RAISE EXCEPTION 'logout event rejected by test';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
      """)

      Repo.query!("""
      CREATE TRIGGER reject_logout_event BEFORE INSERT ON audit_log_events
        FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_logout_event()
      """)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:ok, :revoked_unaudited} = Audited.revoke_session(:user, token)
        end)

      assert log =~ "session revoked without an event kind=user"
      refute log =~ Base.encode64(token)
      refute Repo.get(UserToken, token_id)
      assert events(:user_logged_out) == []
    end

    test "guest and hidden preview sessions are revoked without an event" do
      guest = insert(:user, guest: true)
      hidden = insert(:user, hidden: true)

      for account <- [guest, hidden] do
        token = Accounts.generate_user_session_token(account)
        assert {:ok, :revoked} = Audited.revoke_session(:user, token)
      end

      assert events(:user_logged_out) == []
    end

    test "authors sign out too" do
      author = insert(:author)

      {:ok, %{token: token}} =
        Audited.issue_session(Context.for_actor(author, source: :ui), author, :sso)

      assert {:ok, :revoked} = Audited.revoke_session(:author, token)
      assert [event] = events(:author_logged_out)
      assert event.author_id == author.id
      assert [login] = events(:author_logged_in)
      assert login.details["auth_method"] == "sso"
    end
  end

  describe "web session boundary" do
    setup %{conn: conn} do
      conn =
        conn
        |> Map.replace!(:secret_key_base, OliWeb.Endpoint.config(:secret_key_base))
        |> init_test_session(%{})

      %{conn: conn}
    end

    test "password login and logout record the user's session lifecycle", %{conn: conn} do
      user = insert(:user)

      token = conn |> UserAuth.log_in_user(user) |> get_session(:user_token)
      assert [login] = events(:user_logged_in)
      assert login.details["auth_method"] == "password"

      conn |> put_session(:user_token, token) |> UserAuth.log_out_user()
      assert [logout] = events(:user_logged_out)
      assert logout.details["session_ref"] == login.details["session_ref"]
    end

    test "identity-provider sessions record their method", %{conn: conn} do
      user = insert(:user)
      author = insert(:author)

      UserAuth.create_session(conn, user, :cognito)
      AuthorAuth.create_session(conn, author, :cognito)

      assert [%{details: %{"auth_method" => "cognito"}}] = events(:user_logged_in)
      assert [%{details: %{"auth_method" => "cognito"}}] = events(:author_logged_in)
    end

    test "sessions issued without an authentication are not recorded as logins", %{conn: conn} do
      guest = insert(:user, guest: true)

      UserAuth.create_session(conn, guest)
      assert events(:user_logged_in) == []
    end
  end

  describe "password login when the session cannot be issued" do
    setup do
      Repo.query!("""
      CREATE FUNCTION pg_temp.reject_login_events() RETURNS trigger AS $$
      BEGIN
        IF NEW.event_type IN ('user_logged_in', 'author_logged_in') THEN
          RAISE EXCEPTION 'login event rejected by test';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
      """)

      Repo.query!("""
      CREATE TRIGGER reject_login_events BEFORE INSERT ON audit_log_events
        FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_login_events()
      """)

      :ok
    end

    test "a user sees only the sign-in error and keeps the typed email", %{conn: conn} do
      user = user_fixture()

      ExUnit.CaptureLog.capture_log(fn ->
        conn =
          post(conn, ~p"/users/log_in", %{
            "user" => %{"email" => user.email, "password" => valid_user_password()}
          })

        assert redirected_to(conn) == ~p"/users/log_in"
        refute get_session(conn, :user_token)
        assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "We couldn't sign you in"
        refute Phoenix.Flash.get(conn.assigns.flash, :info)
        assert Phoenix.Flash.get(conn.assigns.flash, :email) == user.email
      end)
    end

    test "an author linking accounts goes back to the link page without the pending link", %{
      conn: conn
    } do
      user = user_fixture()
      author = author_fixture()

      ExUnit.CaptureLog.capture_log(fn ->
        conn =
          conn
          |> log_in_user(user)
          |> post(~p"/authors/log_in", %{
            "author" => %{
              "email" => author.email,
              "password" => valid_author_password(),
              "link_account_user_id" => "#{user.id}"
            }
          })

        assert redirected_to(conn) == ~p"/users/link_account"
        refute get_session(conn, :author_token)
        refute get_session(conn, :link_account_user_id)
        refute Phoenix.Flash.get(conn.assigns.flash, :info)
      end)

      refute Repo.get!(Oli.Accounts.User, user.id).author_id
    end
  end

  defp events(event_type),
    do: Repo.all(from(e in LogEvent, where: e.event_type == ^event_type, order_by: e.id))
end
