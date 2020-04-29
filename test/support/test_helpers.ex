defmodule Oli.TestHelpers do
  import Oli.Utils

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.Accounts.LtiToolConsumer
  alias Oli.Accounts.Author
  alias Oli.Delivery.Lti.HmacSHA1
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

  def lti_consumer_fixture(attrs \\ %{}) do
    params =
      attrs
      |> Enum.into(%{
        info_product_family_code: "code",
        info_version: "1",
        instance_contact_email: "example@example.com",
        instance_guid: "2u9dfh7979hfd",
        instance_name: "none"
      })

    {:ok, consumer} =
      LtiToolConsumer.changeset(%LtiToolConsumer{}, params)
      |> Repo.insert()

      consumer
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
        roles: "none"
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
        consumer_key: "test-consumer-key",
        shared_secret: "test-secret",
        author_id: 1,
      })

    {:ok, institution} = Accounts.create_institution(params)

    institution
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
    scheme = System.get_env("LTI_PROTOCOL", scheme)
    port = if conn.port == 80 or conn.port == 443, do: "", else: ":#{conn.port}"

    "#{scheme}://#{conn.host}#{port}/lti/basic_launch"
  end

  def build_lti_request(req_url, shared_secret, attrs \\ %{}) do
    lti_params = attrs |> Enum.into(%{
      "oauth_consumer_key" => "test-consumer-key",
      "oauth_signature_method" => "HMAC-SHA1",
      "oauth_timestamp" => DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string,
      "oauth_nonce" => random_string(16),
      "oauth_version" => "1.0",
      "context_id" => "some-context-id",
      "context_label" => "Torus",
      "context_title" => "Torus Test",
      "ext_roles" => "urn:lti:instrole:ims/lis/Student,urn:lti:role:ims/lis/Learner,urn:lti:sysrole:ims/lis/User",
      "launch_presentation_document_target" => "iframe",
      "launch_presentation_locale" => "en",
      "launch_presentation_return_url" => "https://canvas.oli.cmu.edu/courses/1/external_content/success/external_tool_redirect",
      "lis_person_contact_email_primary" => "exampleuser@example.edu",
      "lis_person_name_family" => "User",
      "lis_person_name_full" => "Example User",
      "lis_person_name_given" => "Example",
      "lti_message_type" => "basic-lti-launch-request",
      "lti_version" => "LTI-1p0",
      "oauth_callback" => "about:blank",
      "resource_link_id" => "82f5cc6b61288d047fc5213547ac8fba4790bffa",
      "resource_link_title" => "Torus OLI",
      "roles" => "Learner",
      "tool_consumer_info_product_family_code" => "canvas",
      "tool_consumer_info_version" => "cloud",
      "tool_consumer_instance_contact_email" => "admin@canvas.oli.cmu.edu",
      "tool_consumer_instance_guid" => "8865aa05b4b79b64a91a86042e43af5ea8ae79eb.localhost:8900",
      "tool_consumer_instance_name" => "OLI Canvas Admin",
      "user_id" => "dc86d3e58c1025af0b2cce49205ad2cb1019d546",
      "user_image" => "https://canvas.oli.cmu.edu/images/messages/avatar-50.png",
    })

    oauth_signature = HmacSHA1.build_signature(
      req_url,
      "POST",
      unsafe_map_to_keyword_list(lti_params),
      shared_secret
    )

    Map.put(lti_params, "oauth_signature", oauth_signature)
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
