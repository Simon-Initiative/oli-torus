defmodule OliWeb.Common.AssentAuthWebTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory

  alias Oli.Accounts
  alias Oli.AssentAuth.{AuthorAssentAuth, AuthorIdentity, UserAssentAuth}
  alias OliWeb.{AuthorAuth, UserAuth}
  alias OliWeb.Common.AssentAuthWeb

  describe "author assent" do
    setup %{conn: conn} do
      conn = conn |> Phoenix.ConnTest.init_test_session(%{}) |> fetch_session()

      %{conn: conn}
    end

    test "handle_authorization_success/4 handles successful authorization of existing author", %{
      conn: conn
    } do
      author =
        insert(:author, user_identities: [%AuthorIdentity{uid: "123", provider: "google"}])

      provider = "google"

      author_email = author.email
      author_name = author.name

      author = %{
        "email" => author_email,
        "name" => author_name,
        "sub" => "123",
        "email_verified" => true
      }

      config = author_test_config()

      {:ok, :authenticate, conn} =
        AssentAuthWeb.handle_authorization_success(
          conn,
          provider,
          author,
          config
        )

      assert %{email: ^author_email, name: ^author_name} =
               conn.assigns[:current_author]

      # no confirmation email is sent for an already verified email
      Swoosh.TestAssertions.assert_no_email_sent()
    end

    test "handle_authorization_success/4 handles successful authorization of new author", %{
      conn: conn
    } do
      provider = "google"

      author_email = "new_author@example.edu"
      author_name = "New Author"

      author = %{
        "email" => author_email,
        "name" => author_name,
        "sub" => "123",
        "email_verified" => true
      }

      config = author_test_config()

      {:ok, :create_user, _conn} =
        AssentAuthWeb.handle_authorization_success(
          conn,
          provider,
          author,
          config
        )

      # no confirmation email is sent for an already verified email
      Swoosh.TestAssertions.assert_no_email_sent()
    end

    test "handle_authorization_success/4 returns email_confirmation_required", %{
      conn: conn
    } do
      provider = "google"

      author_email = "new_author@example.edu"
      author_name = "New Author"

      author = %{
        "email" => author_email,
        "name" => author_name,
        "sub" => "123"
      }

      config = author_test_config()

      {:email_confirmation_required, :create_user, _conn} =
        AssentAuthWeb.handle_authorization_success(
          conn,
          provider,
          author,
          config
        )

      # no confirmation email is sent for author params with missing email_verified
      [%Oban.Job{args: %{"email" => %{"subject" => "Confirm your email"}}} | _] =
        queued_email_jobs()
    end

    test "handle_authorization_success/4 handles error", %{
      conn: conn
    } do
      provider = "google"

      author_email = "new_author@example.edu"
      author_name = "New Author"

      author = %{
        "email" => author_email,
        "name" => author_name
      }

      config = author_test_config()

      {:error, error, _conn} =
        AssentAuthWeb.handle_authorization_success(
          conn,
          provider,
          author,
          config
        )

      assert error ==
               {:invalid_user_identity_params,
                {:missing_param, "sub",
                 %{
                   "email" => author_email,
                   "name" => author_name
                 }}}
    end
  end

  describe "user assent" do
    setup %{conn: conn} do
      conn = conn |> Phoenix.ConnTest.init_test_session(%{}) |> fetch_session()

      %{conn: conn}
    end

    test "handle_authorization_success/4 creates a new separate user account when LTI user with same email already exists",
         %{
           conn: conn
         } do
      lti_user = insert(:user, independent_learner: false)

      provider = "google"

      user_email = lti_user.email
      user_name = "New Independent Learner"

      user = %{
        "email" => user_email,
        "name" => user_name,
        "sub" => "123",
        "email_verified" => true
      }

      config = user_test_config()

      {:ok, :create_user, _conn} =
        AssentAuthWeb.handle_authorization_success(
          conn,
          provider,
          user,
          config
        )

      independent_user = Accounts.get_independent_user_by_email(user_email)

      assert independent_user.email == user_email
      assert independent_user.name == user_name
      assert independent_user.independent_learner == true
      assert independent_user.email_confirmed_at != nil

      # assert that the new user is not the same as the LTI user
      assert independent_user.id != lti_user.id

      # no confirmation email is sent for an already verified email
      Swoosh.TestAssertions.assert_no_email_sent()
    end
  end

  defp author_test_config(),
    do: %AssentAuthWeb.Config{
      authentication_providers: [
        google: [
          client_id: "some_client_id",
          client_secret: "some_secret",
          strategy: Assent.Strategy.Google
        ]
      ],
      redirect_uri: fn provider -> ~p"/authors/auth/#{provider}/callback" end,
      current_user_assigns_key: :current_author,
      get_user_by_provider_uid: &AuthorAssentAuth.get_user_by_provider_uid(&1, &2),
      create_session: &AuthorAuth.create_session(&1, &2),
      deliver_user_confirmation_instructions: fn user ->
        Accounts.deliver_author_confirmation_instructions(
          user,
          &url(~p"/authors/confirm/#{&1}")
        )
      end,
      assent_auth_module: AuthorAssentAuth
    }

  defp user_test_config(),
    do: %AssentAuthWeb.Config{
      authentication_providers: [
        google: [
          client_id: "some_client_id",
          client_secret: "some_secret",
          strategy: Assent.Strategy.Google
        ]
      ],
      redirect_uri: fn provider -> ~p"/users/auth/#{provider}/callback" end,
      current_user_assigns_key: :current_author,
      get_user_by_provider_uid: &UserAssentAuth.get_user_by_provider_uid(&1, &2),
      create_session: &UserAuth.create_session(&1, &2),
      deliver_user_confirmation_instructions: fn user ->
        Accounts.deliver_user_confirmation_instructions(
          user,
          &url(~p"/users/confirm/#{&1}")
        )
      end,
      assent_auth_module: UserAssentAuth
    }
end
