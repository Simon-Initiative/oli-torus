defmodule Oli.TestHelpers do
  import Ecto.Query, warn: false
  import Mox
  import Oli.Factory

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Institutions
  alias Oli.PartComponents
  alias Oli.Publishing
  alias OliWeb.Common.LtiSession

  Mox.defmock(Oli.Test.MockHTTP, for: HTTPoison.Base)
  Mox.defmock(Oli.Test.MockAws, for: ExAws.Behaviour)

  def yesterday() do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    DateTime.add(datetime, -(60 * 60 * 24), :second)
  end

  def tomorrow() do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    DateTime.add(datetime, 60 * 60 * 24, :second)
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
        timezone: "US/Eastern",
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
        sub: UUID.uuid4(),
        name: "Ms Jane Marie Doe",
        given_name: "Jane",
        family_name: "Doe",
        middle_name: "Marie",
        picture: "https://platform.example.edu/jane.jpg",
        email: "jane#{System.unique_integer([:positive])}@platform.example.edu",
        locale: "en-US"
      })

    {:ok, user} =
      case attrs do
        %{password: _password, password_confirmation: _password_confirmation} ->
          User.changeset(%User{}, params)
          |> Repo.insert()

        _ ->
          User.noauth_changeset(%User{}, params)
          |> Repo.insert()
      end

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
        deployment_id: "1"
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

  def cache_lti_params(lti_params, user_id) do
    {:ok, %{id: id}} = Oli.Lti.LtiParams.create_or_update_lti_params(lti_params, user_id)

    id
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

    publication = Publishing.project_working_publication(project.slug)
    Publishing.upsert_published_resource(publication, revision)

    %{objective: objective, objective_revision: revision}
  end

  def gating_condition_fixture(attrs \\ %{}) do
    {:ok, gating_condition} =
      attrs
      |> Enum.into(%{type: :schedule, data: %{}})
      |> Oli.Delivery.Gating.create_gating_condition()

    gating_condition
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

  def instructor_conn(%{conn: conn}) do
    {:ok, instructor} =
      Accounts.update_user_platform_roles(
        insert(:user, %{can_create_sections: true, independent_learner: true}),
        [Lti_1p3.Tool.PlatformRoles.get_role(:institution_instructor)]
      )

    conn =
      conn
      |> Plug.Test.init_test_session(lti_session: nil)
      |> Pow.Plug.assign_current_user(instructor, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok, conn: conn}
  end

  def lms_instructor_conn(%{conn: conn}) do
    institution = insert(:institution)
    tool_jwk = jwk_fixture()
    registration = insert(:lti_registration, %{tool_jwk_id: tool_jwk.id})
    deployment = insert(:lti_deployment, %{institution: institution, registration: registration})
    instructor = insert(:user)

    lti_param_ids = %{
      instructor:
        cache_lti_params(
          %{
            "iss" => registration.issuer,
            "aud" => registration.client_id,
            "sub" => instructor.sub,
            "exp" => Timex.now() |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix(),
            "https://purl.imsglobal.org/spec/lti/claim/context" => %{
              "id" => "some_id",
              "title" => "some_title"
            },
            "https://purl.imsglobal.org/spec/lti/claim/roles" => [
              "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
            ],
            "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id
          },
          instructor.id
        )
    }

    conn =
      conn
      |> Plug.Test.init_test_session(lti_session: nil)
      |> Pow.Plug.assign_current_user(instructor, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      |> LtiSession.put_session_lti_params(lti_param_ids.instructor)

    {:ok, conn: conn}
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

  def recycle_user_session(conn, user) do
    Phoenix.ConnTest.recycle(conn)
    |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
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
        slug: "test_part_component",
        author: "Test McTesterson"
      })

    {:ok, _registration} = PartComponents.create_registration(params)
  end

  def latest_record_index(table) do
    from(r in table, order_by: [desc: r.id], limit: 1, select: r.id)
    |> Repo.one!()
  end

  def make_sections(project, institution, prefix, n, attrs) do
    65..(65 + (n - 1))
    |> Enum.map(fn value -> List.to_string([value]) end)
    |> Enum.map(fn value -> make(project, institution, "#{prefix}-#{value}", attrs) end)
  end

  def make(project, institution, title, attrs) do
    {:ok, section} =
      Sections.create_section(
        Map.merge(
          %{
            title: title,
            timezone: "1",
            registration_open: true,
            context_id: UUID.uuid4(),
            institution_id:
              if is_nil(institution) do
                nil
              else
                institution.id
              end,
            base_project_id: project.id,
            requires_payment: true,
            amount: "$100.00",
            grace_period_days: 5,
            has_grace_period: true
          },
          attrs
        )
      )

    section
  end

  def set_timezone(%{conn: conn}) do
    timezone = DateTime.utc_now().time_zone

    conn = Plug.Test.init_test_session(conn, %{local_tz: timezone})

    {:ok, conn: conn}
  end
end
