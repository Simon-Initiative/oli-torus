defmodule Oli.TestHelpers do
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing

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
      |> Enum.into(%{end_date: ~D[2010-04-17],
      open_and_free: true,
      registration_open: true,
      start_date: ~D[2010-04-17],
      time_zone: "some time_zone",
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
        email: "ironman#{System.unique_integer([:positive])}@example.com",
        first_name: "Tony",
        last_name: "Stark",
        user_id: "2u9dfh7979hfd",
        user_image: "none",
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
        email: "ironman#{System.unique_integer([:positive])}@example.com",
        first_name: "Tony",
        last_name: "Stark",
        token: "2u9dfh7979hfd",
        provider: "google",
        system_role_id: Accounts.SystemRole.role_id.author,
      })

    {:ok, author} =
      Author.changeset(%Author{}, params)
      |> Repo.insert()

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
        timezone: "US/Eastern",
        author_id: 1,
      })

    {:ok, institution} = Accounts.create_institution(params)

    institution
  end

  def jwk_fixture() do
    %{private_key: private_key} = Oli.Lti_1p3.KeyGenerator.generate_key_pair()
    {:ok, jwk} = Oli.Lti_1p3.create_new_jwk(%{
      pem: private_key,
      typ: "JWT",
      alg: "RS256",
      kid: UUID.uuid4(),
      active: true,
    })

    jwk
  end

  def project_fixture(author) do
    {:ok, project} = Course.create_project("test project", author)
    project
  end

  def objective_fixture(project, author) do
    {:ok, %{resource: objective, revision: revision}} = Course.create_and_attach_resource(
      project,
      %{title: "Test learning objective", author_id: author.id, resource_type_id: Oli.Resources.ResourceType.get_id_by_type("objective")})

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

  def author_conn(%{conn: conn}) do
    author = author_fixture()
    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)

    {:ok, conn: conn, author: author}
  end

  def author_project_conn(%{conn: conn}) do
    author = author_fixture()
    [project | _rest] = make_n_projects(1, author)
    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)

    {:ok, conn: conn, author: author, project: project}
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
    objective = objective_fixture(project, author);
    objective_revision = objective.objective_revision
    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)
    {:ok, conn: conn, author: author, project: project, objective_revision: objective_revision}
  end

  def read_json_file(filename) do
    with {:ok, body} <- File.read(filename),
         {:ok, json} <- Poison.decode(body), do: {:ok, json}
  end
end
