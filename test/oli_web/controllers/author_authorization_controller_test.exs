defmodule OliWeb.AuthorAuthorizationControllerTest do
  # The tests replace the application's author SSO providers.
  use OliWeb.ConnCase, async: false

  import Oli.Factory

  alias Oli.Accounts.AuthorToken
  alias Oli.AssentAuth.AuthorIdentity
  alias Oli.Authoring.Course
  alias Oli.Repo

  defmodule FakeStrategy do
    @moduledoc false

    def authorize_url(_config), do: {:ok, %{url: "https://sso.example.edu", session_params: %{}}}

    def callback(config, _params), do: {:ok, %{user: Keyword.fetch!(config, :user), token: %{}}}
  end

  @provider :fake_sso

  setup do
    previous = Application.get_env(:oli, :author_auth_providers)
    on_exit(fn -> Application.put_env(:oli, :author_auth_providers, previous) end)

    owner = insert(:author)
    project = insert(:project, authors: [owner])
    %{project: project}
  end

  describe "SSO callback with a pending collaborator invitation" do
    test "an existing author signing in accepts the invitation", %{conn: conn, project: project} do
      author = insert(:author)

      Repo.insert!(%AuthorIdentity{
        user_id: author.id,
        provider: "#{@provider}",
        uid: "sso-existing"
      })

      invitation = invite(author, project)

      conn = sso_callback(conn, invitation, %{"sub" => "sso-existing", "email" => author.email})

      assert redirected_to(conn)
      assert collaboration_status(project, author) == :accepted

      assert_audited(:project_collaborator_changed,
        project_id: project.id,
        affected_author_id: author.id,
        actor: author,
        source: :ui
      )
    end

    test "an invited author without an account links SSO and accepts the invitation", %{
      conn: conn,
      project: project
    } do
      author = insert(:author, password_hash: nil, email_confirmed_at: nil)
      invitation = invite(author, project)

      conn = sso_callback(conn, invitation, %{"sub" => "sso-invited", "email" => author.email})

      assert redirected_to(conn)
      assert collaboration_status(project, author) == :accepted

      assert_audited(:project_collaborator_changed,
        project_id: project.id,
        affected_author_id: author.id,
        actor: author,
        source: :ui
      )
    end
  end

  defp invite(author, project) do
    {encoded, token} =
      AuthorToken.build_email_token(author, "collaborator_invitation:#{project.slug}")

    Repo.insert!(token)

    insert(:author_project,
      author_id: author.id,
      project_id: project.id,
      status: :pending_confirmation,
      project_role_id: Oli.Authoring.Authors.ProjectRole.role_id().contributor
    )

    %{token: encoded, project_slug: project.slug}
  end

  defp sso_callback(conn, invitation, user_params) do
    Application.put_env(:oli, :author_auth_providers, [
      {@provider, [strategy: FakeStrategy, user: user_params]}
    ])

    conn
    |> Plug.Test.init_test_session(%{
      invitation_token: invitation.token,
      invitation_project_slug: invitation.project_slug
    })
    |> get(~p"/authors/auth/#{@provider}/callback")
  end

  defp collaboration_status(project, author) do
    Course.get_author_project(project.slug, author.id, filter_by_status: false).status
  end
end
