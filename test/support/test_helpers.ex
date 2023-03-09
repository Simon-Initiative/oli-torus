defmodule Oli.TestHelpers do
  import Ecto.Query, warn: false
  import Mox
  import Oli.Factory

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.{Author, AuthorPreferences, User}
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Institutions
  alias Oli.PartComponents
  alias Oli.Publishing
  alias OliWeb.Common.{LtiSession, SessionContext}
  alias Lti_1p3.Tool.ContextRoles

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
        name: "Example Institution"
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
        issuer: "https://institution.example.edu",
        client_id: "1000000000001",
        key_set_url: "some key_set_url",
        auth_token_url: "some auth_token_url",
        auth_login_url: "some auth_login_url",
        auth_server: "some auth_server",
        line_items_service_domain: "some line_items_service_domain"
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
        key_set_url: "some key_set_url",
        line_items_service_domain: "some line_items_service_domain"
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

  def independent_instructor_conn(context), do: user_conn(context, %{can_create_sections: true})

  def user_conn(%{conn: conn}, attrs \\ %{}) do
    user = user_fixture(attrs)
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

    {:ok, conn: conn, instructor: instructor}
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

    {:ok, conn: conn, instructor: instructor}
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
    admin =
      author_fixture(%{
        system_role_id: Accounts.SystemRole.role_id().admin,
        preferences: %AuthorPreferences{show_relative_dates: false} |> Map.from_struct()
      })

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

  # Sets up a mock to simulate a recaptcha failure
  def expect_recaptcha_http_failure_post() do
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
             "success" => false
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
    |> Enum.map(fn value -> make(project, institution, "#{prefix}#{value}", attrs) end)
  end

  def make(project, institution, title, attrs) do
    {:ok, section} =
      Sections.create_section(
        Map.merge(
          %{
            title: title,
            registration_open: true,
            context_id: UUID.uuid4(),
            institution_id:
              if is_nil(institution) do
                nil
              else
                institution.id
              end,
            base_project_id: project.id,
            customizations: project.customizations,
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

  @doc """
    Creates an open and free section for a given project
  """
  def open_and_free_section(project, attrs) do
    insert(
      :section,
      Map.merge(
        %{
          base_project: project,
          context_id: UUID.uuid4(),
          open_and_free: true,
          registration_open: true,
          display_curriculum_item_numbering: attrs.display_curriculum_item_numbering
        },
        attrs
      )
    )
  end

  @doc """
    Creates and publishes a project with a curriculum composed of a root container, a unit, and a nested page.
  """
  def base_project_with_curriculum(_) do
    project = insert(:project)

    nested_page_resource = insert(:resource)

    nested_page_revision =
      insert(:revision, %{
        objectives: %{"attached" => []},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Nested page 1",
        resource: nested_page_resource
      })

    # Associate nested page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: nested_page_resource.id})

    unit_one_resource = insert(:resource)

    # Associate unit to the project
    insert(:project_resource, %{
      resource_id: unit_one_resource.id,
      project_id: project.id
    })

    unit_one_revision =
      insert(:revision, %{
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [nested_page_resource.id],
        content: %{"model" => []},
        deleted: false,
        title: "The first unit",
        resource: unit_one_resource,
        slug: "first_unit"
      })

    # root container
    container_resource = insert(:resource)

    # Associate root container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [unit_one_resource.id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    # Publication of project with root container
    publication =
      insert(:publication, %{project: project, root_resource_id: container_resource.id})

    # Publish root container resource
    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision
    })

    # Publish nested page resource
    insert(:published_resource, %{
      publication: publication,
      resource: nested_page_resource,
      revision: nested_page_revision
    })

    # Publish unit one resource
    insert(
      :published_resource,
      %{
        resource: unit_one_resource,
        publication: publication,
        revision: unit_one_revision
      }
    )

    %{publication: publication, project: project, unit_one_revision: unit_one_revision}
  end

  def section_with_assessment(_context, deployment \\ nil) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # Graded page revision
    page_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Progress test revision",
        graded: true,
        content: %{"advancedDelivery" => true}
      )

    # Associate nested graded page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_revision.resource.id})

    unit_one_resource = insert(:resource)

    # Associate unit to the project
    insert(:project_resource, %{
      resource_id: unit_one_resource.id,
      project_id: project.id
    })

    unit_one_revision =
      insert(:revision, %{
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "The first unit",
        resource: unit_one_resource,
        slug: "first_unit"
      })

    # root container
    container_resource = insert(:resource)

    # Associate root container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [unit_one_resource.id, page_revision.resource.id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    # Publication of project with root container
    publication =
      insert(:publication, %{project: project, root_resource_id: container_resource.id})

    # Publish root container resource
    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    # Publish nested container resource
    insert(:published_resource, %{
      publication: publication,
      resource: unit_one_resource,
      revision: unit_one_revision,
      author: author
    })

    # Publish nested page resource
    insert(:published_resource, %{
      publication: publication,
      resource: page_revision.resource,
      revision: page_revision,
      author: author
    })

    section =
      if deployment do
        insert(:section,
          base_project: project,
          context_id: UUID.uuid4(),
          lti_1p3_deployment: deployment,
          registration_open: true,
          type: :enrollable
        )
      else
        insert(:section,
          base_project: project,
          context_id: UUID.uuid4(),
          open_and_free: true,
          registration_open: true,
          type: :enrollable
        )
      end

    {:ok, section} = Sections.create_section_resources(section, publication)

    {:ok, section: section, unit_one_revision: unit_one_revision, page_revision: page_revision}
  end

  def project_section_revisions(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # Graded page revision
    page_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Progress test revision",
        graded: true,
        content: %{"advancedDelivery" => true}
      )

    other_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Other test revision",
        graded: true,
        content: %{"advancedDelivery" => true},
        relates_to: [page_revision.resource_id],
        purpose: :application
      )

    # Associate nested graded page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_revision.resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: other_revision.resource.id})

    # root container
    container_resource = insert(:resource)

    # Associate root container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_revision.resource.id, other_revision.resource.id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    # Publication of project with root container
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_resource.id,
        published: nil
      })

    # Publish root container resource
    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    # Publish nested page resource
    insert(:published_resource, %{
      publication: publication,
      resource: page_revision.resource,
      revision: page_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: other_revision.resource,
      revision: other_revision,
      author: author
    })

    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable,
        contains_explorations: true
      )

    {:ok, section} = Sections.create_section_resources(section, publication)

    {:ok,
     project: project,
     section: section,
     page_revision: page_revision,
     other_revision: other_revision}
  end

  def create_section_with_posts(_conn) do
    user = insert(:user)
    author = insert(:author)
    project = insert(:project, authors: [author])

    page_resource = insert(:resource)

    page_revision =
      insert(:revision,
        resource: page_resource,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        content: %{"model" => []},
        title: "Other revision A"
      )

    insert(:project_resource, %{project_id: project.id, resource_id: page_resource.id})

    collab_space_config = build(:collab_space_config, status: :enabled)
    page_resource_cs = insert(:resource)

    page_revision_cs =
      insert(:revision,
        resource: page_resource_cs,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        content: %{"model" => []},
        slug: "page_revision_cs",
        collab_space_config: collab_space_config,
        title: "Other revision B"
      )

    insert(:project_resource, %{project_id: project.id, resource_id: page_resource_cs.id})

    container_resource = insert(:resource)

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_resource.id, page_resource_cs.id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_resource.id,
        published: nil
      })

    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_resource,
      revision: page_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_resource_cs,
      revision: page_revision_cs,
      author: author
    })

    section = insert(:section, base_project: project, type: :enrollable)
    {:ok, _sr} = Sections.create_section_resources(section, publication)

    insert(:post, section: section, resource: page_resource_cs, user: user)

    insert(:post,
      content: %{message: "Other post"},
      section: section,
      resource: page_resource_cs,
      user: user
    )

    other_user_1 = insert(:user)
    other_user_2 = insert(:user)

    insert(:post, section: section, resource: page_resource_cs, user: other_user_1)
    insert(:post, section: section, resource: page_resource_cs, user: other_user_2)

    [
      project: project,
      publication: publication,
      page_revision: page_revision,
      page_revision_cs: page_revision_cs,
      section: section,
      author: author,
      user: user,
      page_resource_cs: page_resource_cs
    ]
  end

  def enroll_user_to_section(user, section, role) do
    Sections.enroll(user.id, section.id, [
      ContextRoles.get_role(role)
    ])
  end

  def set_timezone(%{conn: conn}) do
    conn = Plug.Test.init_test_session(conn, %{browser_timezone: "America/New_York"})

    {:ok, conn: conn, context: SessionContext.init(conn)}
  end

  def utc_datetime_to_localized_datestring(utc_datetime, timezone) do
    datestring =
      utc_datetime
      |> Timex.to_datetime(timezone)
      |> DateTime.to_naive()
      |> NaiveDateTime.to_iso8601()

    Regex.replace(~r/:\d\d\z/, datestring, "")
  end

  def load_stripe_config(), do: load_stripe_config(nil)

  def load_stripe_config(_conn) do
    load_env_file("test/config/stripe_config.exs")
  end

  def reset_test_payment_config() do
    load_env_file("test/config/config.exs")
  end

  defp load_env_file(path) do
    path
    |> Config.Reader.read!()
    |> Application.put_all_env()
  end

  @doc """
  Renders an html binary to a file in test-results/<module_path>/output.html
  for easier debugging of tests that verify html content.

  Examples:
    ```
    conn = get(Routes.resource_path(OliWeb.Endpoint, :edit, project_slug, page_revision_slug))

    inspect_html_file(html_response(conn, 200))

    ...
    ```
  """
  defmacro inspect_html_file(html) do
    quote do
      path_parts =
        ["test-results", "html"]
        |> Enum.concat(
          Module.split(__MODULE__)
          |> Enum.map(&String.downcase/1)
        )

      dir = Path.join(path_parts)

      filepath =
        path_parts
        |> Enum.concat(["output.html"])
        |> Path.join()

      File.mkdir_p!(dir)
      File.write!(filepath, unquote(html))

      IO.write("\nhtml file rendered to #{filepath}\n")
    end
  end
end
