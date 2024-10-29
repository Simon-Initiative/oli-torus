defmodule Oli.TestHelpers do
  import Ecto.Query, warn: false
  import Mox
  import Oli.Factory

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.{Author, AuthorPreferences, User}
  alias Oli.Activities
  alias Oli.Analytics.Summary
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Institutions
  alias Oli.PartComponents
  alias Oli.Publishing
  alias OliWeb.Common.{LtiSession, SessionContext}
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Gating.GatingConditionData
  alias Oli.Resources.ResourceType
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Page.PageContext

  Mox.defmock(Oli.Test.MockHTTP, for: HTTPoison.Base)
  Mox.defmock(Oli.Test.MockAws, for: ExAws.Behaviour)
  Mox.defmock(Oli.Test.MockOpenAIClient, for: Oli.OpenAIClient)
  Mox.defmock(Oli.Test.DateTimeMock, for: Oli.DateTime)
  Mox.defmock(Oli.Test.DateMock, for: Oli.Date)

  defmodule CustomDispatcher do
    @moduledoc """
    Custom dispatcher for testing PubSub messages emitted by broadcast_from/5.
    """

    @doc """
    Dispatches messages to the given list of pids.
    When used as a custom dispatcher in the broadcast_from/5 function, it converts it into broadcast/3 calls,
    meaning that all the nodes (including the current process) receive the message.
    """
    def dispatch(entries, _from, message) do
      for {pid, _metadata} <- entries do
        send(pid, message)
      end

      :ok
    end
  end

  def stub_real_current_time(%{conn: conn}) do
    stub_real_current_time()
    {:ok, conn: conn}
  end

  def stub_real_current_time(), do: stub_current_time(DateTime.utc_now())

  def stub_current_time(utc_now) do
    Mox.stub(Oli.Test.DateTimeMock, :utc_now, fn -> utc_now end)

    Mox.stub(Oli.Test.DateTimeMock, :now!, fn timezone ->
      DateTime.shift_zone!(utc_now, timezone)
    end)

    Mox.stub(Oli.Test.DateMock, :utc_today, fn -> DateTime.to_date(utc_now) end)
  end

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
          resource_type_id: Oli.Resources.ResourceType.id_for_objective()
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

  def guest_conn(%{conn: conn}) do
    guest = user_fixture(%{guest: true})
    conn = Pow.Plug.assign_current_user(conn, guest, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    {:ok, conn: conn, guest: guest}
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
        system_role_id: Accounts.SystemRole.role_id().system_admin,
        preferences: %AuthorPreferences{show_relative_dates: false} |> Map.from_struct()
      })

    conn =
      Pow.Plug.assign_current_user(conn, admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, conn: conn, admin: admin}
  end

  def account_admin_conn(%{conn: conn}) do
    account_admin =
      author_fixture(%{
        system_role_id: Accounts.SystemRole.role_id().account_admin,
        preferences: %AuthorPreferences{show_relative_dates: false} |> Map.from_struct()
      })

    conn =
      Pow.Plug.assign_current_user(
        conn,
        account_admin,
        OliWeb.Pow.PowHelpers.get_pow_config(:author)
      )

    {:ok, conn: conn, account_admin: account_admin}
  end

  def content_admin_conn(%{conn: conn}) do
    content_admin =
      author_fixture(%{
        system_role_id: Accounts.SystemRole.role_id().content_admin,
        preferences: %AuthorPreferences{show_relative_dates: false} |> Map.from_struct()
      })

    conn =
      Pow.Plug.assign_current_user(
        conn,
        content_admin,
        OliWeb.Pow.PowHelpers.get_pow_config(:author)
      )

    {:ok, conn: conn, content_admin: content_admin}
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
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Nested page 1",
        resource: nested_page_resource
      })

    # Associate nested page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: nested_page_resource.id})

    nested_page_resource_2 = insert(:resource)

    nested_page_revision_2 =
      insert(:revision, %{
        objectives: %{"attached" => []},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Nested page 2",
        resource: nested_page_resource_2,
        graded: true
      })

    # Associate nested page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: nested_page_resource_2.id})

    unit_one_resource = insert(:resource)

    # Associate unit to the project
    insert(:project_resource, %{
      resource_id: unit_one_resource.id,
      project_id: project.id
    })

    unit_one_revision =
      insert(:revision, %{
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [nested_page_resource.id, nested_page_resource_2.id],
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
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [unit_one_resource.id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    # Publication of project with root container
    publication =
      insert(:publication, %{
        project: project,
        published: nil,
        root_resource_id: container_resource.id
      })

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

    # Publish nested page resource 2
    insert(:published_resource, %{
      publication: publication,
      resource: nested_page_resource_2,
      revision: nested_page_revision_2
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

    %{
      publication: publication,
      project: project,
      unit_one_revision: unit_one_revision,
      nested_page_revision: nested_page_revision,
      nested_page_revision_2: nested_page_revision_2
    }
  end

  def section_with_assessment(_context, deployment \\ nil) do
    author = insert(:author)

    project = insert(:project, authors: [author])

    # Graded page revision
    page_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Progress test revision",
        graded: true,
        content: %{"advancedDelivery" => true}
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Other test revision",
        graded: true,
        content: %{"advancedDelivery" => true}
      )

    # Associate nested graded page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_revision.resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: page_2_revision.resource.id})

    unit_one_resource = insert(:resource)

    # Associate unit to the project
    insert(:project_resource, %{
      resource_id: unit_one_resource.id,
      project_id: project.id
    })

    unit_one_revision =
      insert(:revision, %{
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
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
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [unit_one_resource.id, page_revision.resource.id, page_2_revision.resource.id],
        content: %{},
        deleted: false,
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

    insert(:published_resource, %{
      publication: publication,
      resource: page_2_revision.resource,
      revision: page_2_revision,
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

    # Create new unpublished publication for the project
    new_publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_resource.id,
        published: nil
      })

    insert(:published_resource, %{
      publication: new_publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: new_publication,
      resource: unit_one_resource,
      revision: unit_one_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: new_publication,
      resource: page_revision.resource,
      revision: page_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: new_publication,
      resource: page_2_revision.resource,
      revision: page_2_revision,
      author: author
    })

    {:ok,
     section: section,
     unit_one_revision: unit_one_revision,
     page_revision: page_revision,
     page_2_revision: page_2_revision}
  end

  def create_project_with_products(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # Create page 1
    page_resource_1 = insert(:resource)

    page_revision_1 =
      insert(:revision, %{
        objectives: %{},
        resource_type_id: ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page 1",
        resource: page_resource_1,
        slug: "page_1"
      })

    # Associate page 1 to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource_1.id})

    # Create page 2
    page_resource_2 = insert(:resource)

    page_revision_2 =
      insert(:revision, %{
        objectives: %{},
        resource_type_id: ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page 2",
        resource: page_resource_2,
        slug: "page_2"
      })

    # Associate page 2 to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource_2.id})

    # module container
    module_resource = insert(:resource)

    module_revision =
      insert(:revision, %{
        resource: module_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: [page_resource_2.id],
        content: %{},
        deleted: false,
        slug: "module_container",
        title: "Module Container"
      })

    # Associate module to the project
    insert(:project_resource, %{project_id: project.id, resource_id: module_resource.id})

    # unit container
    unit_resource = insert(:resource)

    unit_revision =
      insert(:revision, %{
        resource: unit_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: [module_resource.id],
        content: %{},
        deleted: false,
        slug: "unit_container",
        title: "Unit Container"
      })

    # Associate unit to the project
    insert(:project_resource, %{project_id: project.id, resource_id: unit_resource.id})

    # root container
    container_resource = insert(:resource)

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: [unit_resource.id, page_resource_1.id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    # Associate root container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    # Publication of project with root container
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_resource.id
      })

    # Publish root container resource
    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    # Publish unit resource
    insert(:published_resource, %{
      author: author,
      publication: publication,
      resource: unit_resource,
      revision: unit_revision
    })

    # Publish module resource
    insert(:published_resource, %{
      author: author,
      publication: publication,
      resource: module_resource,
      revision: module_revision
    })

    # Publish page 1 resource
    insert(:published_resource, %{
      author: author,
      publication: publication,
      resource: page_resource_1,
      revision: page_revision_1
    })

    # Publish page 2 resource
    insert(:published_resource, %{
      author: author,
      publication: publication,
      resource: page_resource_2,
      revision: page_revision_2
    })

    product_1 =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: false,
        registration_open: false,
        type: :blueprint,
        title: "Product 1",
        slug: "product_1"
      )

    product_2 =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: false,
        registration_open: false,
        type: :blueprint,
        title: "Product 2",
        slug: "product_2"
      )

    {:ok, product_1} = Sections.create_section_resources(product_1, publication)
    Sections.rebuild_contained_pages(product_1)

    {:ok, product_2} = Sections.create_section_resources(product_2, publication)
    Sections.rebuild_contained_pages(product_2)

    # Create new unpublished publication for the project
    new_publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_resource.id,
        published: nil
      })

    insert(:published_resource, %{
      publication: new_publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    insert(:published_resource, %{
      author: author,
      publication: new_publication,
      resource: unit_resource,
      revision: unit_revision
    })

    insert(:published_resource, %{
      author: author,
      publication: new_publication,
      resource: module_resource,
      revision: module_revision
    })

    insert(:published_resource, %{
      author: author,
      publication: new_publication,
      resource: page_resource_1,
      revision: page_revision_1
    })

    insert(:published_resource, %{
      author: author,
      publication: new_publication,
      resource: page_resource_2,
      revision: page_revision_2
    })

    %{
      project: project,
      product_1: product_1,
      product_2: product_2,
      page_resource_1: page_resource_1,
      page_resource_2: page_resource_2
    }
  end

  def create_project_with_objectives(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # Create objective 1
    obj_resource_1 = insert(:resource)

    obj_revision_1 =
      insert(:revision, %{
        resource: obj_resource_1,
        objectives: %{},
        resource_type_id: ResourceType.id_for_objective(),
        children: [],
        content: %{},
        deleted: false,
        slug: "objective_1",
        title: "Objective 1"
      })

    # Associate objective 1 to the project
    insert(:project_resource, %{project_id: project.id, resource_id: obj_resource_1.id})

    # Create objective 2
    obj_resource_2 = insert(:resource)

    obj_revision_2 =
      insert(:revision, %{
        resource: obj_resource_2,
        objectives: %{},
        resource_type_id: ResourceType.id_for_objective(),
        children: [],
        content: %{},
        deleted: false,
        slug: "objective_2",
        title: "Objective 2"
      })

    # Associate objective 2 to the project
    insert(:project_resource, %{project_id: project.id, resource_id: obj_resource_2.id})

    # Create page 1
    page_resource_1 = insert(:resource)

    page_revision_1 =
      insert(:revision, %{
        objectives: %{"attached" => [obj_resource_1.id]},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page 1",
        resource: page_resource_1,
        slug: "page_1"
      })

    # Associate page 1 to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource_1.id})

    # Create page 2
    page_resource_2 = insert(:resource)

    page_revision_2 =
      insert(:revision, %{
        objectives: %{"attached" => [obj_resource_2.id]},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page 2",
        resource: page_resource_2,
        slug: "page_2"
      })

    # Associate page 2 to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource_2.id})

    # module container
    module_resource = insert(:resource)

    module_revision =
      insert(:revision, %{
        resource: module_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: [page_resource_2.id],
        content: %{},
        deleted: false,
        slug: "module_container",
        title: "Module Container"
      })

    # Associate module to the project
    insert(:project_resource, %{project_id: project.id, resource_id: module_resource.id})

    # unit container
    unit_resource = insert(:resource)

    unit_revision =
      insert(:revision, %{
        resource: unit_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: [module_resource.id],
        content: %{},
        deleted: false,
        slug: "unit_container",
        title: "Unit Container"
      })

    # Associate unit to the project
    insert(:project_resource, %{project_id: project.id, resource_id: unit_resource.id})

    # root container
    container_resource = insert(:resource)

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: [unit_resource.id, page_resource_1.id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    # Associate root container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    # Publication of project with root container
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_resource.id
      })

    # Publish root container resource
    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    # Publish unit resource
    insert(:published_resource, %{
      author: author,
      publication: publication,
      resource: unit_resource,
      revision: unit_revision
    })

    # Publish module resource
    insert(:published_resource, %{
      author: author,
      publication: publication,
      resource: module_resource,
      revision: module_revision
    })

    # Publish page 1 resource
    insert(:published_resource, %{
      author: author,
      publication: publication,
      resource: page_resource_1,
      revision: page_revision_1
    })

    # Publish page 2 resource
    insert(:published_resource, %{
      author: author,
      publication: publication,
      resource: page_resource_2,
      revision: page_revision_2
    })

    # Publish objective 1 resource
    insert(:published_resource, %{
      author: author,
      publication: publication,
      resource: obj_resource_1,
      revision: obj_revision_1
    })

    # Publish objective 2 resource
    insert(:published_resource, %{
      author: author,
      publication: publication,
      resource: obj_resource_2,
      revision: obj_revision_2
    })

    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    Sections.rebuild_contained_pages(section)

    %{
      project: project,
      section: section,
      publication: publication,
      obj_revision_1: obj_revision_1,
      obj_revision_2: obj_revision_2,
      module_revision: module_revision
    }
  end

  def create_full_project_with_objectives(_conn), do: create_full_project_with_objectives()

  def create_full_project_with_objectives() do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # Create objectives
    {obj_resource_a, obj_revision_a} = create_objective("Objective A", "objective_A", project)
    {obj_resource_b, obj_revision_b} = create_objective("Objective B", "objective_B", project)
    {obj_resource_c1, obj_revision_c1} = create_objective("Objective C1", "objective_C1", project)

    {obj_resource_c, obj_revision_c} =
      create_objective("Objective C", "objective_C", project, [obj_resource_c1.id])

    {obj_resource_d, obj_revision_d} = create_objective("Objective D", "objective_D", project)
    {obj_resource_e, obj_revision_e} = create_objective("Objective E", "objective_E", project)
    {obj_resource_f, obj_revision_f} = create_objective("Objective F", "objective_F", project)

    # Create activities
    {act_resource_x, act_revision_x} = create_activity("Activity X", "activity_x", project)

    {act_resource_y, act_revision_y} =
      create_activity("Activity Y", "activity_y", project, [obj_resource_c.id, obj_resource_c1.id])

    {act_resource_z, act_revision_z} =
      create_activity("Activity Z", "activity_z", project, [obj_resource_d.id])

    {act_resource_w, act_revision_w} =
      create_activity("Activity W", "activity_w", project, [obj_resource_e.id, obj_resource_f.id])

    # Create pages
    build_content_for_page = fn activity_ids ->
      Enum.with_index(activity_ids, fn activity_id, id ->
        %{
          "activity_id" => activity_id,
          "id" => id,
          "type" => "activity-reference"
        }
      end)
    end

    {page_resource_1, page_revision_1} =
      create_page("Page 1", "page_1", project, build_content_for_page.([act_resource_x.id]), [
        obj_resource_a.id
      ])

    # Page with grouped activities
    page_2_model = [
      %{
        "type" => "group",
        "id" => 1,
        "purpose" => "didigetthis",
        "children" => build_content_for_page.([act_resource_y.id, act_resource_z.id])
      }
    ]

    {page_resource_2, page_revision_2} =
      create_page(
        "Page 2",
        "page_2",
        project,
        page_2_model,
        [obj_resource_b.id]
      )

    {page_resource_3, page_revision_3} =
      create_page("Page 3", "page_3", project, build_content_for_page.([act_resource_w.id]))

    # Create modules
    {module_resource_1, module_revision_1} =
      create_container("Module Container 1", "module_container_1", project, [page_resource_2.id])

    {module_resource_2, module_revision_2} =
      create_container("Module Container 2", "module_container_2", project, [page_resource_3.id])

    # Create Unit
    {unit_resource, unit_revision} =
      create_container("Unit Container", "unit_container", project, [module_resource_1.id])

    # Create Root
    {root_resource, root_revision} =
      create_container("Root Container", "root_container", project, [
        page_resource_1.id,
        unit_resource.id,
        module_resource_2.id
      ])

    # Publication of project with root container
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: root_resource.id,
        published: nil
      })

    # Publish all resources
    [
      {obj_resource_a, obj_revision_a},
      {obj_resource_b, obj_revision_b},
      {obj_resource_c, obj_revision_c},
      {obj_resource_c1, obj_revision_c1},
      {obj_resource_d, obj_revision_d},
      {obj_resource_e, obj_revision_e},
      {obj_resource_f, obj_revision_f},
      {act_resource_x, act_revision_x},
      {act_resource_y, act_revision_y},
      {act_resource_z, act_revision_z},
      {act_resource_w, act_revision_w},
      {page_resource_1, page_revision_1},
      {page_resource_2, page_revision_2},
      {page_resource_3, page_revision_3},
      {module_resource_1, module_revision_1},
      {module_resource_2, module_revision_2},
      {unit_resource, unit_revision},
      {root_resource, root_revision}
    ]
    |> Enum.each(fn {resource, revision} ->
      insert(:published_resource, %{
        publication: publication,
        resource: resource,
        revision: revision,
        author: author
      })
    end)

    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    Sections.rebuild_contained_pages(section)

    %{
      project: project,
      section: section,
      publication: publication,
      resources: %{
        obj_resource_a: obj_resource_a,
        obj_resource_b: obj_resource_b,
        obj_resource_c: obj_resource_c,
        obj_resource_c1: obj_resource_c1,
        obj_resource_d: obj_resource_d,
        obj_resource_e: obj_resource_e,
        obj_resource_f: obj_resource_f,
        page_resource_1: page_resource_1,
        page_resource_2: page_resource_2,
        page_resource_3: page_resource_3,
        module_resource_1: module_resource_1,
        module_resource_2: module_resource_2,
        unit_resource: unit_resource,
        root_resource: root_resource,
        act_revision_w: act_revision_w,
        act_resource_x: act_resource_x,
        act_resource_y: act_resource_y,
        act_resource_z: act_resource_z
      },
      revisions: %{
        obj_revision_a: obj_revision_a,
        obj_revision_b: obj_revision_b,
        obj_revision_c: obj_revision_c,
        obj_revision_c1: obj_revision_c1,
        obj_revision_d: obj_revision_d,
        obj_revision_e: obj_revision_e,
        obj_revision_f: obj_revision_f,
        page_revision_1: page_revision_1,
        page_revision_2: page_revision_2,
        page_revision_3: page_revision_3,
        module_revision_1: module_revision_1,
        module_revision_2: module_revision_2,
        unit_revision: unit_revision,
        root_revision: root_revision,
        act_revision_w: act_revision_w,
        act_revision_x: act_revision_x,
        act_revision_y: act_revision_y,
        act_revision_z: act_revision_z
      }
    }
  end

  def create_project_with_units_and_modules(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    {act_resource_w, act_revision_w} = create_activity("Activity W", "activity_w", project)

    # Create pages
    build_content_for_page = fn activity_ids ->
      Enum.with_index(activity_ids, fn activity_id, id ->
        %{
          "activity_id" => activity_id,
          "id" => id,
          "type" => "activity-reference"
        }
      end)
    end

    {page_resource_1, page_revision_1} =
      create_page("Page 1", "page_1", project, build_content_for_page.([act_resource_w.id]))

    {page_resource_2, page_revision_2} =
      create_page(
        "Page 2",
        "page_2",
        project,
        build_content_for_page.([act_resource_w.id])
      )

    {page_resource_3, page_revision_3} =
      create_page("Page 3", "page_3", project, build_content_for_page.([act_resource_w.id]))

    # Create modules
    {module_resource_1, module_revision_1} =
      create_container("Module Container 1", "module_container_1", project, [page_resource_2.id])

    # Create Unit
    {unit_resource, unit_revision} =
      create_container("Unit Container", "unit_container", project, [module_resource_1.id])

    # Create Root
    {root_resource, root_revision} =
      create_container("Root Container", "root_container", project, [
        page_resource_1.id,
        unit_resource.id
      ])

    # Publication of project with root container
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: root_resource.id
      })

    # Publish all resources
    [
      {act_resource_w, act_revision_w},
      {page_resource_1, page_revision_1},
      {page_resource_2, page_revision_2},
      {page_resource_3, page_revision_3},
      {module_resource_1, module_revision_1},
      {unit_resource, unit_revision},
      {root_resource, root_revision}
    ]
    |> Enum.each(fn {resource, revision} ->
      insert(:published_resource, %{
        publication: publication,
        resource: resource,
        revision: revision,
        author: author
      })
    end)

    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    Sections.rebuild_contained_pages(section)

    %{
      project: project,
      section: section,
      publication: publication,
      resources: %{
        page_resource_1: page_resource_1,
        page_resource_2: page_resource_2,
        page_resource_3: page_resource_3,
        module_resource_1: module_resource_1,
        unit_resource: unit_resource,
        root_resource: root_resource
      },
      revisions: %{
        page_revision_1: page_revision_1,
        page_revision_2: page_revision_2,
        page_revision_3: page_revision_3,
        module_revision_1: module_revision_1,
        unit_revision: unit_revision,
        root_revision: root_revision
      }
    }
  end

  defp create_objective(title, slug, project, subobjectives \\ []) do
    obj_resource = insert(:resource)

    obj_revision =
      insert(:revision, %{
        resource: obj_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_objective(),
        children: subobjectives,
        content: %{},
        deleted: false,
        slug: slug,
        title: title
      })

    # Associate objective to the project
    insert(:project_resource, %{project_id: project.id, resource_id: obj_resource.id})

    {obj_resource, obj_revision}
  end

  defp create_activity(title, slug, project, objectives \\ []) do
    activity_resource = insert(:resource)

    activity_revision =
      insert(:revision, %{
        objectives: %{"1" => objectives},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.id_for_activity(),
        activity_type_id: Activities.get_registration_by_slug("oli_multiple_choice").id,
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: title,
        resource: activity_resource,
        slug: slug
      })

    # Associate activity to the project
    insert(:project_resource, %{project_id: project.id, resource_id: activity_resource.id})

    {activity_resource, activity_revision}
  end

  defp create_page(title, slug, project, content_model, objectives \\ []) do
    page_resource = insert(:resource)

    page_revision =
      insert(:revision, %{
        objectives: %{"attached" => objectives},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.id_for_page(),
        children: [],
        content: %{"model" => content_model},
        deleted: false,
        title: title,
        resource: page_resource,
        slug: slug
      })

    # Associate page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource.id})

    {page_resource, page_revision}
  end

  defp create_container(title, slug, project, children) do
    container_resource = insert(:resource)

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: children,
        content: %{},
        deleted: false,
        slug: slug,
        title: title
      })

    # Associate container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    {container_resource, container_revision}
  end

  defp generate_attempt_content(),
    do: %{
      choices: [
        %{
          id: "option_1_id",
          content: [
            %{
              children: [
                %{
                  text: "A lot"
                }
              ]
            }
          ]
        },
        %{
          id: "option_2_id",
          content: [
            %{
              children: [
                %{
                  text: "None"
                }
              ]
            }
          ]
        }
      ]
    }

  def section_with_survey(_context, opts \\ [survey_enabled: true]) do
    author = insert(:author)

    # Project survey
    survey_question_resource = insert(:resource)

    mcq_reg = Activities.get_registration_by_slug("oli_multiple_choice")

    survey_question_revision =
      insert(:revision,
        resource: survey_question_resource,
        resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
        activity_type_id: mcq_reg.id,
        title: "Experience",
        content: generate_attempt_content()
      )

    survey_resource = insert(:resource)

    survey_revision =
      insert(:revision,
        resource: survey_resource,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        content: %{
          model: [
            %{
              id: "4286170280",
              type: "content",
              children: [
                %{
                  id: "2905665054",
                  type: "p",
                  children: [
                    %{
                      text: ""
                    }
                  ]
                }
              ]
            },
            %{
              id: "3330767711",
              type: "activity-reference",
              children: [],
              activity_id: survey_question_resource.id
            }
          ],
          bibrefs: [],
          version: "0.1.0"
        },
        author_id: author.id,
        title: "Course Survey"
      )

    project = insert(:project, required_survey_resource_id: survey_resource.id, authors: [author])

    # Associate survey to the project
    insert(:project_resource, %{project_id: project.id, resource_id: survey_resource.id})

    # Create page 1
    page_resource = insert(:resource)

    page_revision =
      insert(:revision, %{
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page 1",
        resource: page_resource,
        slug: "page_1"
      })

    # Associate page 1 to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource.id})

    # root container
    container_resource = insert(:resource)

    # Associate root container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [page_resource.id],
        content: %{},
        deleted: false,
        title: "Root Container"
      })

    # Publication of project with root container
    publication =
      insert(:publication, %{project: project, root_resource_id: container_resource.id})

    # Publish project survey
    insert(:published_resource, %{
      publication: publication,
      resource: survey_resource,
      revision: survey_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: survey_question_resource,
      revision: survey_question_revision,
      author: author
    })

    # Publish page resource
    insert(:published_resource, %{
      author: author,
      publication: publication,
      resource: page_resource,
      revision: page_revision
    })

    # Publish root container resource
    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable,
        required_survey_resource_id: (opts[:survey_enabled] && survey_resource.id) || nil
      )

    {:ok, section} = Sections.create_section_resources(section, publication)

    # Create new unpublished publication for the project
    new_publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_resource.id,
        published: nil
      })

    insert(:published_resource, %{
      publication: new_publication,
      resource: survey_resource,
      revision: survey_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: new_publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    {:ok, section: section, survey: survey_revision, survey_questions: [survey_question_revision]}
  end

  def create_survey_access(student, section, survey, survey_questions) do
    create_activity_attempts(student, section, survey, survey_questions, "active")
  end

  def complete_student_survey(student, section, survey, survey_questions) do
    create_activity_attempts(student, section, survey, survey_questions, "evaluated")
  end

  defp create_activity_attempts(student, section, survey, survey_questions, status) do
    resource_access =
      insert(:resource_access, user: student, section: section, resource: survey.resource)

    resource_attempt = insert(:resource_attempt, resource_access: resource_access)

    activity_attempts =
      Enum.map(survey_questions, fn question ->
        insert(:activity_attempt,
          resource_attempt: resource_attempt,
          revision: question,
          lifecycle_state: status,
          transformed_model: generate_attempt_content()
        )
      end)

    Enum.map(activity_attempts, fn attempt ->
      insert(:part_attempt,
        activity_attempt: attempt,
        response: %{files: [], input: "option_1_id"}
      )
    end)
  end

  def sections_with_same_publications(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])
    user_1 = insert(:user)
    user_2 = insert(:user)

    # Create page 1
    page_resource_1 = insert(:resource)
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource_1.id})

    page_1_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Page 1",
        graded: false,
        resource: page_resource_1
      )

    # Create page 2
    page_resource_2 = insert(:resource)
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource_2.id})

    page_2_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Page 2",
        graded: true,
        resource: page_resource_2
      )

    # Create root container for the project
    root_container_resource = insert(:resource)
    insert(:project_resource, %{project_id: project.id, resource_id: root_container_resource.id})

    root_container_revision =
      insert(:revision, %{
        resource: root_container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [
          page_resource_1.id,
          page_resource_2.id
        ],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    # Publicate project
    publication =
      insert(:publication, %{project: project, root_resource_id: root_container_resource.id})

    insert(:published_resource, %{
      publication: publication,
      resource: root_container_resource,
      revision: root_container_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_resource_1,
      revision: page_1_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_resource_2,
      revision: page_2_revision
    })

    # Create section 1
    section_1 =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        registration_open: true,
        type: :enrollable
      )

    # create section 2
    section_2 =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        registration_open: true,
        type: :enrollable
      )

    resource_access_1 =
      insert(:resource_access, user: user_1, section: section_1, resource: page_resource_1)

    resource_access_2 =
      insert(:resource_access, user: user_2, section: section_2, resource: page_resource_2)

    resource_attempt_1 = insert(:resource_attempt, resource_access: resource_access_1)
    resource_attempt_2 = insert(:resource_attempt, resource_access: resource_access_2)

    activity_attempt_1 =
      insert(:activity_attempt,
        resource_attempt: resource_attempt_1,
        revision: page_1_revision,
        lifecycle_state: "active",
        transformed_model: generate_attempt_content()
      )

    activity_attempt_2 =
      insert(:activity_attempt,
        resource_attempt: resource_attempt_2,
        revision: page_1_revision,
        lifecycle_state: "active",
        transformed_model: generate_attempt_content()
      )

    insert(:part_attempt,
      activity_attempt: activity_attempt_1,
      response: %{files: [], input: "option_1_id"}
    )

    insert(:part_attempt,
      activity_attempt: activity_attempt_2,
      response: %{files: [], input: "option_2_id"}
    )

    insert(:snapshot, %{
      section: section_1,
      resource: page_1_revision.resource,
      user: user_1,
      correct: true
    })

    insert(:snapshot, %{
      section: section_2,
      resource: page_1_revision.resource,
      user: user_2,
      correct: true
    })

    {:ok, section_1} = Sections.create_section_resources(section_1, publication)
    {:ok, section_2} = Sections.create_section_resources(section_2, publication)

    %{
      section_1: section_1,
      section_2: section_2,
      user_1: user_1,
      user_2: user_2
    }
  end

  def section_with_gating_conditions(_context) do
    author = insert(:author)
    project = insert(:project, authors: [author])
    student = insert(:user, %{family_name: "Example", given_name: "Student1"})
    student_2 = insert(:user, %{family_name: "Example", given_name: "Student2"})

    # Create graded pages
    graded_page_1_resource = insert(:resource)
    graded_page_2_resource = insert(:resource)
    graded_page_3_resource = insert(:resource)
    graded_page_4_resource = insert(:resource)
    graded_page_5_resource = insert(:resource)
    graded_page_6_resource = insert(:resource)

    insert(:project_resource, %{project_id: project.id, resource_id: graded_page_1_resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: graded_page_2_resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: graded_page_3_resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: graded_page_4_resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: graded_page_5_resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: graded_page_6_resource.id})

    graded_page_1_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Graded page 1 - Level 1 (w/ no date)",
        graded: true,
        resource: graded_page_1_resource
      )

    graded_page_2_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Graded page 2 - Level 0 (w/ date)",
        graded: true,
        purpose: :application,
        resource: graded_page_2_resource
      )

    graded_page_3_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Graded page 3 - Level 1 (w/ no date)",
        graded: true,
        resource: graded_page_3_resource,
        relates_to: [graded_page_1_resource.id, graded_page_2_resource.id]
      )

    graded_page_4_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Graded page 4 - Level 0 (w/ gating condition)",
        graded: true,
        resource: graded_page_4_resource
      )

    graded_page_5_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Graded page 5 - Level 0 (w/ student gating condition)",
        graded: true,
        resource: graded_page_5_resource,
        relates_to: [graded_page_4_resource.id]
      )

    graded_page_6_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Graded page 6 - Level 0 (w/o student gating condition)",
        graded: true,
        resource: graded_page_6_resource
      )

    # Create a unit inside the project
    unit_one_resource = insert(:resource)

    insert(:project_resource, %{
      resource_id: unit_one_resource.id,
      project_id: project.id
    })

    unit_one_revision =
      insert(:revision, %{
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [graded_page_1_resource.id, graded_page_2_resource.id],
        content: %{"model" => []},
        deleted: false,
        title: "Unit #1",
        resource: unit_one_resource,
        slug: "first_unit"
      })

    # Create root container for the project
    root_container_resource = insert(:resource)
    insert(:project_resource, %{project_id: project.id, resource_id: root_container_resource.id})

    root_container_revision =
      insert(:revision, %{
        resource: root_container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [
          unit_one_resource.id,
          graded_page_3_resource.id,
          graded_page_4_resource.id,
          graded_page_5_resource.id,
          graded_page_6_resource.id
        ],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    # Publicate project, container, pages and unit
    publication =
      insert(:publication, %{project: project, root_resource_id: root_container_resource.id})

    insert(:published_resource, %{
      publication: publication,
      resource: root_container_resource,
      revision: root_container_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: graded_page_1_resource,
      revision: graded_page_1_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: graded_page_2_resource,
      revision: graded_page_2_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: graded_page_3_resource,
      revision: graded_page_3_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: graded_page_4_resource,
      revision: graded_page_4_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: graded_page_5_resource,
      revision: graded_page_5_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: graded_page_6_resource,
      revision: graded_page_6_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_one_resource,
      revision: unit_one_revision
    })

    # Create section
    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)

    enroll_user_to_section(student, section, :context_learner)
    enroll_user_to_section(student_2, section, :context_learner)

    insert(:gating_condition, %{
      section: section,
      resource: graded_page_4_resource,
      type: :schedule,
      user: nil,
      data: %GatingConditionData{end_datetime: ~U[2023-01-12 13:30:00Z]}
    })

    insert(:gating_condition, %{
      section: section,
      resource: graded_page_5_resource,
      type: :schedule,
      user: nil,
      data: %GatingConditionData{end_datetime: ~U[2023-06-05 14:00:00Z]}
    })

    insert(:gating_condition, %{
      section: section,
      resource: graded_page_5_resource,
      type: :schedule,
      user: student,
      data: %GatingConditionData{end_datetime: ~U[2023-07-08 14:00:00Z]}
    })

    insert(:gating_condition, %{
      section: section,
      resource: graded_page_6_resource,
      type: :always_open,
      user: student,
      data: %GatingConditionData{end_datetime: nil}
    })

    insert(:gating_condition, %{
      section: section,
      resource: graded_page_5_resource,
      type: :schedule,
      user: student_2,
      data: %GatingConditionData{end_datetime: ~U[2023-07-08 14:00:00Z]}
    })

    insert(:gating_condition, %{
      section: section,
      resource: graded_page_6_resource,
      type: :always_open,
      user: student_2,
      data: %GatingConditionData{end_datetime: nil}
    })

    %{
      section: section,
      graded_page_1: graded_page_1_revision,
      graded_page_2: graded_page_2_revision,
      graded_page_3: graded_page_3_revision,
      graded_page_4: graded_page_4_revision,
      graded_page_5: graded_page_5_revision,
      graded_page_6: graded_page_6_revision,
      student_with_gating_condition: student,
      student_with_gating_condition_2: student_2
    }
  end

  def section_with_deadlines(_context) do
    author = insert(:author)
    project = insert(:project, authors: [author])
    student = insert(:user, %{family_name: "Example", given_name: "Student1"})
    student_2 = insert(:user, %{family_name: "Example", given_name: "Student2"})

    # Create graded pages
    graded_page_1_resource = insert(:resource)
    graded_page_2_resource = insert(:resource)
    graded_page_3_resource = insert(:resource)
    graded_page_4_resource = insert(:resource)
    graded_page_5_resource = insert(:resource)
    graded_page_6_resource = insert(:resource)
    unreachable_graded_page_1_resource = insert(:resource)
    unreachable_graded_page_2_resource = insert(:resource)

    insert(:project_resource, %{project_id: project.id, resource_id: graded_page_1_resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: graded_page_2_resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: graded_page_3_resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: graded_page_4_resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: graded_page_5_resource.id})
    insert(:project_resource, %{project_id: project.id, resource_id: graded_page_6_resource.id})

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unreachable_graded_page_1_resource.id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unreachable_graded_page_2_resource.id
    })

    unreachable_graded_page_1_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Unreachable Graded page 1",
        graded: true,
        resource: unreachable_graded_page_1_resource
      )

    unreachable_graded_page_2_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Unreachable Graded page 2",
        graded: true,
        resource: unreachable_graded_page_2_resource
      )

    graded_page_1_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Graded page 1 - Level 1 (w/ no date)",
        graded: true,
        content: %{
          model: [
            %{
              id: "3093117657",
              type: "content",
              children: [
                %{id: "2497044625", type: "p", children: [%{text: ""}]},
                %{
                  id: "8761552",
                  type: "page_link",
                  idref: unreachable_graded_page_2_revision.resource_id,
                  purpose: "none",
                  children: [%{text: ""}]
                },
                %{id: "1535128821", type: "p", children: [%{text: ""}]}
              ]
            }
          ],
          bibrefs: [],
          version: "0.1.0"
        },
        resource: graded_page_1_resource
      )

    graded_page_2_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Graded page 2 - Level 0 (w/ date)",
        graded: true,
        purpose: :application,
        content: %{
          model: [
            %{
              id: "3093117658",
              type: "content",
              children: [
                %{id: "2497044626", type: "p", children: [%{text: ""}]},
                %{
                  id: "8761553",
                  type: "page_link",
                  idref: unreachable_graded_page_1_revision.resource_id,
                  purpose: "none",
                  children: [%{text: ""}]
                },
                %{id: "1535128822", type: "p", children: [%{text: ""}]}
              ]
            }
          ],
          bibrefs: [],
          version: "0.1.0"
        },
        resource: graded_page_2_resource
      )

    graded_page_3_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Graded page 3 - Level 1 (w/ no date)",
        graded: true,
        resource: graded_page_3_resource,
        relates_to: [graded_page_1_resource.id, graded_page_2_resource.id]
      )

    graded_page_4_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Graded page 4 - Level 0 (w/ gating condition)",
        graded: true,
        resource: graded_page_4_resource
      )

    graded_page_5_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Graded page 5 - Level 0 (w/ student gating condition)",
        graded: true,
        resource: graded_page_5_resource,
        relates_to: [graded_page_4_resource.id]
      )

    graded_page_6_revision =
      insert(
        :revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Graded page 6 - Level 0 (w/o student gating condition)",
        graded: true,
        resource: graded_page_6_resource
      )

    # Create a unit inside the project
    unit_one_resource = insert(:resource)

    insert(:project_resource, %{
      resource_id: unit_one_resource.id,
      project_id: project.id
    })

    unit_one_revision =
      insert(:revision, %{
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [graded_page_1_resource.id, graded_page_2_resource.id],
        content: %{"model" => []},
        deleted: false,
        title: "Unit #1",
        resource: unit_one_resource,
        slug: "first_unit"
      })

    # Create root container for the project
    root_container_resource = insert(:resource)
    insert(:project_resource, %{project_id: project.id, resource_id: root_container_resource.id})

    root_container_revision =
      insert(:revision, %{
        resource: root_container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [
          unit_one_resource.id,
          graded_page_3_resource.id,
          graded_page_4_resource.id,
          graded_page_5_resource.id,
          graded_page_6_resource.id
        ],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    # Publicate project, container, pages and unit
    publication =
      insert(:publication, %{project: project, root_resource_id: root_container_resource.id})

    insert(:published_resource, %{
      publication: publication,
      resource: root_container_resource,
      revision: root_container_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: graded_page_1_resource,
      revision: graded_page_1_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: graded_page_2_resource,
      revision: graded_page_2_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: graded_page_3_resource,
      revision: graded_page_3_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: graded_page_4_resource,
      revision: graded_page_4_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: graded_page_5_resource,
      revision: graded_page_5_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unreachable_graded_page_1_resource,
      revision: unreachable_graded_page_1_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unreachable_graded_page_2_resource,
      revision: unreachable_graded_page_2_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: graded_page_6_resource,
      revision: graded_page_6_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_one_resource,
      revision: unit_one_revision
    })

    # Create section
    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)

    enroll_user_to_section(student, section, :context_learner)
    enroll_user_to_section(student_2, section, :context_learner)

    sr1 = Sections.get_section_resource(section.id, graded_page_4_resource.id)
    sr2 = Sections.get_section_resource(section.id, graded_page_5_resource.id)
    sr3 = Sections.get_section_resource(section.id, unreachable_graded_page_1_resource.id)
    sr4 = Sections.get_section_resource(section.id, unreachable_graded_page_2_resource.id)

    Sections.update_section_resource(sr1, %{
      scheduling_type: :due_by,
      end_date: ~U[2023-01-12 13:30:00Z]
    })

    Sections.update_section_resource(sr2, %{
      scheduling_type: :due_by,
      end_date: ~U[2023-06-05 14:00:00Z]
    })

    Sections.update_section_resource(sr3, %{
      numbering_level: 1,
      numbering_index: 9
    })

    Sections.update_section_resource(sr4, %{
      numbering_level: 1,
      numbering_index: 8
    })

    %{
      section: section,
      graded_page_1: graded_page_1_revision,
      graded_page_2: graded_page_2_revision,
      graded_page_3: graded_page_3_revision,
      graded_page_4: graded_page_4_revision,
      graded_page_5: graded_page_5_revision,
      graded_page_6: graded_page_6_revision
    }
  end

  def section_without_pages(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # root container
    container_resource = insert(:resource)

    # Associate root container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [],
        content: %{},
        deleted: false,
        collab_space_config: nil,
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

    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)

    %{section: section}
  end

  def section_with_assessment_without_collab_space(_context, deployment \\ nil) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # Graded page revision
    page_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
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
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
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
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [unit_one_resource.id, page_revision.resource.id],
        content: %{},
        deleted: false,
        collab_space_config: nil,
        title: "Root Container without collab space"
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

    {:ok, %{section: section, unit_one_revision: unit_one_revision, page_revision: page_revision}}
  end

  def create_project_with_collab_space_and_posts() do
    user = insert(:user)
    author = insert(:author)
    project = insert(:project, authors: [author])

    # Create collab space
    collab_space_config = build(:collab_space_config)

    # Create page with collab space
    page_resource_cs = insert(:resource)

    page_revision_cs =
      insert(:revision, %{
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.id_for_page(),
        collab_space_config: collab_space_config,
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page with collab",
        resource: page_resource_cs,
        slug: "page_collab"
      })

    # Associate page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource_cs.id})

    # Create page
    page_resource = insert(:resource)

    page_revision =
      insert(:revision, %{
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page 1",
        resource: page_resource,
        slug: "page_one",
        collab_space_config: nil
      })

    # Associate page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource.id})

    # Create collab space for root container
    root_container_collab_space_config = build(:collab_space_config, %{status: :enabled})

    # root container
    container_resource = insert(:resource)

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: [page_resource_cs.id, page_resource.id],
        content: %{},
        collab_space_config: root_container_collab_space_config,
        deleted: false,
        title: "Root Container"
      })

    # Associate root container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    # Publication of project with root container
    publication =
      insert(:publication, %{
        project: project,
        published: nil,
        root_resource_id: container_resource.id
      })

    # Publish root container resource
    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    # Publish page resource
    insert(:published_resource, %{
      author: hd(project.authors),
      publication: publication,
      resource: page_resource,
      revision: page_revision
    })

    # Publish page with collab space resource
    insert(:published_resource, %{
      author: hd(project.authors),
      publication: publication,
      resource: page_resource_cs,
      revision: page_revision_cs
    })

    section = insert(:section, base_project: project)
    {:ok, _root_section_resource} = Sections.create_section_resources(section, publication)

    first_post = insert(:post, section: section, resource: page_resource_cs, user: user)

    second_post =
      insert(:post,
        status: :submitted,
        content: %{message: "Other post"},
        section: section,
        resource: page_resource_cs,
        user: user
      )

    {:ok,
     %{
       project: project,
       publication: publication,
       page_revision: page_revision,
       page_revision_cs: page_revision_cs,
       page_resource_cs: page_resource_cs,
       collab_space_config: collab_space_config,
       root_container_collab_space_config: root_container_collab_space_config,
       author: author,
       section: section,
       posts: [first_post, second_post]
     }}
  end

  def section_with_pages(%{
        author: author,
        revisions: revisions,
        revision_section_attributes: revision_section_attributes
      }) do
    project = insert(:project, %{authors: [author]})

    revisions = Enum.zip(revisions, revision_section_attributes)

    # Create project resource for each revision
    Enum.each(revisions, fn {revision = %Oli.Resources.Revision{}, _section_attributes} ->
      insert(:project_resource, %{project_id: project.id, resource_id: revision.resource.id})
    end)

    # Create project container
    container_revision =
      insert(:revision, %{
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children:
          Enum.map(revisions, fn {revision = %Oli.Resources.Revision{}, _section_attributes} ->
            revision.resource.id
          end),
        content: %{},
        deleted: false,
        title: "Root Container"
      })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: container_revision.resource.id
    })

    # Create project publication
    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource.id})

    # Publish container
    insert(:published_resource, %{
      publication: publication,
      resource: container_revision.resource,
      revision: container_revision
    })

    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    # Publish revisions
    Enum.each(revisions, fn {revision = %Oli.Resources.Revision{}, section_attributes} ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision
      })

      insert(
        :section_resource,
        Map.merge(
          %{
            section: section,
            project: project,
            resource_id: revision.resource.id
          },
          section_attributes
        )
      )
    end)

    # Set the section root resource
    container_revision_section_resource =
      insert(
        :section_resource,
        section: section,
        project: project,
        resource_id: container_revision.resource.id
      )

    {:ok, section} =
      section
      |> Section.changeset(%{
        root_section_resource_id: container_revision_section_resource.id
      })
      |> Repo.update()

    # Insert section project publication
    insert(:section_project_publication, %{
      project: project,
      section: section,
      publication: publication
    })

    {:ok, section: section, project: project, author: author}
  end

  def section_with_pages(
        %{
          revisions: _revisions,
          revision_section_attributes: _revision_section_attributes
        } = attrs
      ) do
    author = insert(:author)

    section_with_pages(Map.put(attrs, :author, author))
  end

  def section_with_pages(
        %{
          revisions: revisions
        } = attrs
      ) do
    author = insert(:author)
    revision_section_attributes = Enum.map(revisions, fn _ -> %{} end)

    section_with_pages(
      Map.merge(attrs, %{author: author, revision_section_attributes: revision_section_attributes})
    )
  end

  def project_section_revisions(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # Graded page revision
    page_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Progress test revision",
        graded: true,
        content: %{"advancedDelivery" => true}
      )

    other_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
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
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
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
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "Other revision A"
      )

    insert(:project_resource, %{project_id: project.id, resource_id: page_resource.id})

    collab_space_config = build(:collab_space_config, status: :enabled)
    page_resource_cs = insert(:resource)

    page_revision_cs =
      insert(:revision,
        resource: page_resource_cs,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
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
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
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

  def basic_section(_, attrs \\ %{}) do
    project = insert(:project)

    page_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        title: "Basic Page"
      })

    insert(:project_resource, %{project_id: project.id, resource_id: page_revision.resource.id})

    container_resource = insert(:resource)
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [page_revision.resource.id],
        content: %{},
        deleted: false
      })

    publication =
      insert(:publication, %{
        project: project,
        published: DateTime.utc_now(),
        root_resource_id: container_resource.id
      })

    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_revision.resource,
      revision: page_revision,
      author: insert(:author, email: "some_email@email.com")
    })

    section =
      insert(
        :section,
        Map.merge(
          %{
            base_project: project,
            open_and_free: true,
            type: :enrollable
          },
          attrs
        )
      )

    {:ok, section} = Sections.create_section_resources(section, publication)

    section_project_publication =
      from(
        spp in Oli.Delivery.Sections.SectionsProjectsPublications,
        where: spp.section_id == ^section.id and spp.project_id == ^project.id,
        limit: 1
      )
      |> Repo.one()

    %{
      section: section,
      publication: section_project_publication,
      project: project,
      section_page: page_revision
    }
  end

  def enroll_user_to_section(user, section, role) do
    Sections.enroll(user.id, section.id, [
      ContextRoles.get_role(role)
    ])
  end

  def ensure_user_visit(user, section) do
    case Sections.Enrollment
         |> where([e], e.user_id == ^user.id and e.section_id == ^section.id)
         |> limit(1)
         |> Repo.one() do
      nil ->
        {:error, nil}

      enrollment ->
        enrollment
        |> Sections.Enrollment.changeset(%{state: %{has_visited_once: true}})
        |> Repo.update()
    end
  end

  def set_timezone(%{conn: conn}) do
    conn = Plug.Test.init_test_session(conn, %{browser_timezone: "America/New_York"})

    {:ok, conn: conn, ctx: SessionContext.init(conn)}
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

  def load_cashnet_config(), do: load_cashnet_config(nil)

  def load_cashnet_config(_conn) do
    load_env_file("test/config/cashnet_config.exs")
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
  Inspect the given html content in the browser. Useful for debugging test that produce html.
  Similar to LiveView test helper, open_browser/1, but does not require a LiveView session.

  Example:
    ```
    open_browser_html(html_response(conn, 200))
    ```
  """
  def open_browser_html(html) do
    html
    |> write_tmp_html_file()
    |> open_with_system_cmd()
  end

  defp write_tmp_html_file(html) do
    path =
      Path.join([
        System.tmp_dir!(),
        "#{Phoenix.LiveView.Utils.random_id()}.html"
      ])

    File.write!(path, html)

    IO.write("\nhtml file rendered to #{path}\n")

    path
  end

  defp open_with_system_cmd(path) do
    {cmd, args} =
      case :os.type() do
        {:win32, _} ->
          {"cmd", ["/c", "start", path]}

        {:unix, :darwin} ->
          {"open", [path]}

        {:unix, _} ->
          if System.find_executable("cmd.exe") do
            {"cmd.exe", ["/c", "start", path]}
          else
            {"xdg-open", [path]}
          end
      end

    System.cmd(cmd, args)
  end

  def unzip_to_memory(data) do
    File.write("export.zip", data)
    result = :zip.unzip(to_charlist("export.zip"), [:memory])
    File.rm!("export.zip")

    case result do
      {:ok, entries} -> entries
      _ -> []
    end
  end

  # Required in order to prevent '(Postgrex.Error) ERROR 25001 (active_sql_transaction): SET TRANSACTION ISOLATION LEVEL must be called before any query' error from occurring in tests
  # https://stackoverflow.com/questions/54169171/phoenix-elixir-testing-when-setting-isolation-level-of-transaction/57328722#57328722
  def setup_tags(tags) do
    if tags[:isolation] do
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)
      Ecto.Adapters.SQL.Sandbox.checkout(Repo, isolation: tags[:isolation])
    else
      Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    end

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    end

    :ok
  end

  def visit_page(page_revision, section, enrolled_user) do
    activity_provider = &Oli.Delivery.ActivityProvider.provide/6
    datashop_session_id = UUID.uuid4()

    effective_settings =
      Settings.get_combined_settings(page_revision, section.id, enrolled_user.id)

    PageContext.create_for_visit(
      section,
      page_revision.slug,
      enrolled_user,
      datashop_session_id
    )

    {:ok, {_status, _ra}} =
      PageLifecycle.visit(
        page_revision,
        section.slug,
        datashop_session_id,
        enrolled_user,
        effective_settings,
        activity_provider
      )
  end

  ### Begins helpers to create resources ###
  def create_bundle_for(type_id, project, author, publication, resource \\ nil, opts \\ [])

  def create_bundle_for(type_id, project, author, nil, nil, opts) do
    resource = insert(:resource)
    publication = insert(:publication, project: project, root_resource_id: resource.id)

    create_bundle_for(type_id, project, author, publication, resource, opts)
    |> Map.merge(%{publication: publication})
  end

  def create_bundle_for(type_id, project, author, publication, nil, opts),
    do: create_bundle_for(type_id, project, author, publication, insert(:resource), opts)

  def create_bundle_for(type_id, project, author, publication, resource, opts) do
    insert(:project_resource, project_id: project.id, resource_id: resource.id)
    title = Keyword.get(opts, :title, title_for(resource.id))
    slug = Keyword.get(opts, :slug, slug_for(resource.id))
    graded = Keyword.get(opts, :graded, false)

    revision =
      insert(:revision,
        resource: resource,
        author: author,
        resource_type_id: type_id,
        title: title,
        slug: slug,
        graded: graded
      )

    insert(:published_resource,
      publication: publication,
      resource: resource,
      revision: revision
    )

    %{resource: resource, revision: revision}
  end

  def create_project_with_assocs(opts \\ [])
  def create_project_with_assocs([]), do: insert(:project, authors: [insert(:author)])

  def create_project_with_assocs([{:authors, []}]), do: create_project_with_assocs()

  def create_project_with_assocs([{:authors, authors}]) when is_list(authors),
    do: insert(:project, authors: authors)

  def assoc_resources(resources, container_revision, container_resource, publication) do
    resources
    |> Enum.map(& &1.id)
    |> Enum.concat(container_revision.children)
    |> set_container_children(container_resource, container_revision, publication)
  end

  def add_resource_summary([prj, pub, section, user, resource, part, type, nc, na, nh, nfa, nfac]) do
    Summary.create_resource_summary(%{
      project_id: prj,
      publication_id: pub,
      section_id: section,
      user_id: user,
      resource_id: resource,
      part_id: part,
      resource_type_id: type,
      num_correct: nc,
      num_attempts: na,
      num_hints: nh,
      num_first_attempts: nfa,
      num_first_attempts_correct: nfac
    })
  end

  defp set_container_children(children, container, container_revision, publication) do
    {:ok, updated_revision} =
      Oli.Resources.create_revision_from_previous(container_revision, %{children: children})

    Publishing.get_published_resource!(publication.id, container.id)
    |> Publishing.update_published_resource(%{revision_id: updated_revision.id})

    updated_revision
  end

  def get_section_resource_by_resource(resource) do
    from(sr in SectionResource,
      join: s in assoc(sr, :section),
      join: r in assoc(sr, :resource),
      where: r.id == ^resource.id
    )
    |> Repo.one()
  end

  defp title_for(resource_id), do: "Container title for resource_id-#{resource_id}"
  defp slug_for(resource_id), do: "slug_for_resource_id_#{resource_id}"

  ### Ends helpers to create resources ###

  ### Begins helper that waits for Tasks to complete ###

  def wait_for_completion() do
    pids = Task.Supervisor.children(Oli.TaskSupervisor)
    Enum.each(pids, &Process.monitor/1)
    wait_for_pids(pids)
  end

  defp wait_for_pids([]), do: nil

  defp wait_for_pids(pids) do
    receive do
      {:DOWN, _ref, :process, pid, _reason} -> wait_for_pids(List.delete(pids, pid))
    end
  end

  ### Ends helper that waits for Tasks to complete ###

  @doc """
  Waits for the given condition to be true. The condition is checked every `interval` milliseconds.
  """
  def wait_while(f, opts \\ []) do
    wait_while_helper(
      f,
      Keyword.get(opts, :interval, 100),
      Keyword.get(opts, :timeout, 5000),
      :os.system_time(:millisecond)
    )
  end

  defp wait_while_helper(f, interval, timeout, start) do
    if :os.system_time(:millisecond) - start > timeout do
      throw("Timeout waiting for condition to be true. Timeout: #{timeout} ms.")
    else
      case f.() do
        true ->
          :timer.sleep(interval)
          wait_while_helper(f, interval, timeout, start)

        false ->
          :ok
      end
    end
  end

  def create_hyperlink_content(revision_2_slug) do
    %{
      "model" => [
        %{
          "children" => [
            %{
              "children" => [
                %{"text" => " "},
                %{
                  "children" => [%{"text" => "link"}],
                  "href" => "/course/link/#{revision_2_slug}",
                  "id" => "1914651063",
                  "target" => "self",
                  "type" => "a",
                  "linkType" => "page"
                },
                %{"text" => ""}
              ],
              "id" => "3636822762",
              "type" => "p"
            }
          ],
          "id" => "481882791",
          "purpose" => "None",
          "type" => "content"
        }
      ]
    }
  end

  def create_page_link_content(revision_2_resource_id) do
    """
    {
    "model": [
      {
        "id": "961779836",
        "type": "content",
        "editor": "slate",
        "children": [
          {
            "id": "3761056253",
            "type": "p",
            "children": [
              {
                "text": ""
              }
            ]
          },
          {
            "id": "3722062784",
            "type": "page_link",
            "idref": "#{revision_2_resource_id}",
            "purpose": "none",
            "children": [
              {
                "text": ""
              }
            ]
          },
          {
            "id": "2711915655",
            "type": "p",
            "children": [
              {
                "text": ""
              }
            ]
          }
        ],
        "textDirection": "ltr"
      }
    ],
    "bibrefs": [],
    "version": "0.1.0"
    }
    """
    |> Jason.decode!()
  end
end
