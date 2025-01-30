defmodule OliWeb.Common.AssentAuthWebTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory

  alias Oli.Accounts
  alias Oli.AssentAuth.{AuthorAssentAuth, AuthorIdentity}
  alias OliWeb.AuthorAuth
  alias OliWeb.Common.AssentAuthWeb
  alias OliWeb.Common.AssentAuthWeb.AssentAuthWebConfig
  alias Swoosh.TestAssertions

  defp test_config(),
    do: %AssentAuthWebConfig{
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

  describe "assent" do
    setup %{conn: conn} do
      conn = conn |> Phoenix.ConnTest.init_test_session(%{}) |> fetch_session()

      %{conn: conn}
    end

    test "handle_authorization_success/5 handles successful authorization of existing author", %{
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

      other_params = %{}
      config = test_config()

      {:ok, conn} =
        AssentAuthWeb.handle_authorization_success(
          conn,
          provider,
          author,
          other_params,
          config
        )

      assert %{email: ^author_email, name: ^author_name} =
               conn.assigns[:current_author]

      # no confirmation email is sent for an already verified email
      TestAssertions.assert_no_email_sent()
    end

    test "handle_authorization_success/5 handles successful authorization of new author", %{
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

      other_params = %{}
      config = test_config()

      {:ok, _conn} =
        AssentAuthWeb.handle_authorization_success(
          conn,
          provider,
          author,
          other_params,
          config
        )

      # no confirmation email is sent for author params with missing email_verified
      [%Oban.Job{args: %{"email" => %{"subject" => "Confirm your email"}}} | _] =
        queued_email_jobs()
    end
  end
end
