defmodule Oli.TestHelpers do
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Institutions
  alias Oli.Accounts.User
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing
  alias Oli.PartComponents

  import Mox

  Mox.defmock(Oli.Test.MockHTTP, for: HTTPoison.Base)
  Mox.defmock(Oli.Test.MockAws, for: ExAws.Behaviour)

  def yesterday() do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    DateTime.add(datetime, -(60 * 60 * 24), :second)
  end

  def now() do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    datetime
  end

  def section_fixture(attrs \\ %{}) do
    params =
      attrs
      |> Enum.into(%{
        open_and_free: false,
        registration_open: true,
        time_zone: "US/Eastern",
        title: "some title",
        context_id: "context_id"
      })

    {:ok, section} =
      Section.changeset(%Section{}, params)
      |> Repo.insert()

    section
  end

  def user_fixture(attrs \\ %{}) do
    params =
      attrs
      |> Enum.into(%{
        sub: "a6d5c443-1f51-4783-ba1a-7686ffe3b54a",
        name: "Ms Jane Marie Doe",
        given_name: "Jane",
        family_name: "Doe",
        middle_name: "Marie",
        picture: "https://platform.example.edu/jane.jpg",
        email: "jane#{System.unique_integer([:positive])}@platform.example.edu",
        locale: "en-US"
      })

    {:ok, user} =
      User.changeset(%User{}, params)
      |> Repo.insert()

    user
  end

  def author_fixture(attrs \\ %{}) do
    params =
      attrs
      |> Enum.into(%{
        email: "author#{System.unique_integer([:positive])}@example.edu",
        given_name: "Test",
        family_name: "Author",
        system_role_id: Accounts.SystemRole.role_id().author
      })

    {:ok, author} =
      case attrs do
        %{password: _password, password_confirmation: _password_confirmation} ->
          Author.changeset(%Author{}, params)
          |> Repo.insert()

        _ ->
          Author.noauth_changeset(%Author{}, params)
          |> Repo.insert()
      end

    author
  end

  def institution_fixture(attrs \\ %{}) do
    params =
      attrs
      |> Enum.into(%{
        country_code: "US",
        institution_email: "institution@example.edu",
        institution_url: "institution.example.edu",
        name: "Example Institution",
        timezone: "US/Eastern"
      })

    {:ok, institution} = Institutions.create_institution(params)

    institution
  end

  def pending_registration_fixture(attrs \\ %{}) do
    params =
      attrs
      |> Enum.into(%{
        name: "Example Institution",
        country_code: "US",
        institution_email: "example@example.edu",
        institution_url: "institution.example.edu",
        timezone: "US/Eastern",
        issuer: "https://institution.example.edu",
        client_id: "1000000000001",
        key_set_url: "some key_set_url",
        auth_token_url: "some auth_token_url",
        auth_login_url: "some auth_login_url",
        auth_server: "some auth_server"
      })

    {:ok, pending_registration} = Institutions.create_pending_registration(params)

    pending_registration
  end

  def registration_fixture(attrs \\ %{}) do
    params =
      attrs
      |> Enum.into(%{
        auth_login_url: "some auth_login_url",
        auth_server: "some auth_server",
        auth_token_url: "some auth_token_url",
        client_id: "some client_id",
        issuer: "some issuer",
        key_set_url: "some key_set_url"
      })

    {:ok, registration} = Institutions.create_registration(params)

    registration
  end

  def deployment_fixture(attrs \\ %{}) do
    params =
      attrs
      |> Enum.into(%{
        deployment_id: "some deployment_id"
      })

    {:ok, deployment} = Institutions.create_deployment(params)

    deployment
  end

  def jwk_fixture() do
    %{private_key: private_key} = Lti_1p3.KeyGenerator.generate_key_pair()

    {:ok, jwk} =
      Lti_1p3.create_jwk(%Lti_1p3.Jwk{
        pem: private_key,
        typ: "JWT",
        alg: "RS256",
        kid: UUID.uuid4(),
        active: true
      })

    jwk
  end

  def cache_lti_params(key, lti_params) do
    {:ok, _lti_params} =
      Lti_1p3.DataProviders.EctoProvider.create_or_update_lti_params(%Lti_1p3.Tool.LtiParams{
        key: key,
        params: lti_params,
        exp: Timex.from_unix(lti_params["exp"])
      })
  end

  def project_fixture(author, title \\ "test project") do
    {:ok, project} = Course.create_project(title, author)
    project
  end

  def objective_fixture(project, author) do
    {:ok, %{resource: objective, revision: revision}} =
      Course.create_and_attach_resource(
        project,
        %{
          title: "Test learning objective",
          author_id: author.id,
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("objective")
        }
      )

    publication = Publishing.get_unpublished_publication_by_slug!(project.slug)
    Publishing.upsert_published_resource(publication, revision)

    %{objective: objective, objective_revision: revision}
  end

  def url_from_conn(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    port = if conn.port == 80 or conn.port == 443, do: "", else: ":#{conn.port}"

    "#{scheme}://#{conn.host}#{port}/lti/basic_launch"
  end

  def make_n_projects(0, _author), do: []

  def make_n_projects(n, author) do
    1..n
    |> Enum.map(fn _ -> Course.create_project("test project", author) end)
    |> Enum.map(fn {:ok, %{project: project}} -> project end)
  end

  def create_empty_project(attrs \\ %{}) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  def user_conn(%{conn: conn}) do
    user = user_fixture()
    conn = Pow.Plug.assign_current_user(conn, user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok, conn: conn, user: user}
  end

  def author_conn(%{conn: conn}) do
    author = author_fixture()

    conn =
      Pow.Plug.assign_current_user(conn, author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, conn: conn, author: author}
  end

  def author_project_conn(%{conn: conn}) do
    author = author_fixture()
    [project | _rest] = make_n_projects(1, author)

    conn =
      Pow.Plug.assign_current_user(conn, author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, conn: conn, author: author, project: project}
  end

  def admin_conn(%{conn: conn}) do
    admin = author_fixture(%{system_role_id: Accounts.SystemRole.role_id().admin})

    conn =
      Pow.Plug.assign_current_user(conn, admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, conn: conn, admin: admin}
  end

  def recycle_author_session(conn, author) do
    Phoenix.ConnTest.recycle(conn)
    |> Pow.Plug.assign_current_user(author, OliWeb.Pow.PowHelpers.get_pow_config(:author))
  end

  def author_project_fixture(), do: author_project_fixture(nil)

  def author_project_fixture(_conn) do
    author = author_fixture()
    [project | _rest] = make_n_projects(1, author)
    {:ok, author: author, project: project}
  end

  def author_project_objective_fixture(%{conn: conn}) do
    author = author_fixture()
    [project | _rest] = make_n_projects(1, author)
    objective = objective_fixture(project, author)
    objective_revision = objective.objective_revision

    conn =
      Pow.Plug.assign_current_user(conn, author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, conn: conn, author: author, project: project, objective_revision: objective_revision}
  end

  def read_json_file(filename) do
    with {:ok, body} <- File.read(filename), {:ok, json} <- Poison.decode(body), do: {:ok, json}
  end

  def expect_recaptcha_http_post() do
    verify_recaptcha_url = Application.fetch_env!(:oli, :recaptcha)[:verify_url]

    Oli.Test.MockHTTP
    |> expect(:post, fn ^verify_recaptcha_url, _body, _headers, _opts ->
      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body:
           Jason.encode!(%{
             "challenge_ts" => "some-challenge-ts",
             "hostname" => "testkey.google.com",
             "success" => true
           })
       }}
    end)
  end

  def part_component_registration_fixture(attrs \\ %{}) do
    params =
      attrs
      |> Enum.into(%{
        authoring_script: "test_part_component_authoring.js",
        authoring_element: "test-part-component-authoring",
        delivery_script: "test_part_component_delivery.js",
        delivery_element: "test-part-component-delivery",
        globally_available: false,
        description: "test part component for testing",
        title: "Test Part Component",
        icon: "nothing",
        slug: "test_part_component"
      })

    {:ok, _registration} = PartComponents.create_registration(params)
  end
end
