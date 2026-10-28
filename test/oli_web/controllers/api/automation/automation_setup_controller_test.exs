defmodule OliWeb.Api.AutomationSetupControllerTest do
  use OliWeb.ConnCase
  use Oban.Testing, repo: Oli.Repo
  @moduletag capture_log: true

  alias Oli.AutomationSetup
  alias Oli.AutomationSetup.ProjectTeardownWorker
  alias OliWeb.Api.AutomationSetupController
  alias Oli.Resources.Revision
  alias Oli.Accounts
  alias Oli.Accounts.SystemRole
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources.Resource
  import Oli.Utils
  import Oli.Factory
  import Ecto.Query, warn: false

  @password "automation password"

  setup [:api_key_seed, :create_project]

  describe "AutomationSetupController" do
    test "Set up and tear down automation test data", %{conn: conn, api_key: api_key} do
      # Note: This can be slightly confusing because this is testing the AutomationSetupController, the purpose
      #       of which is to create automated test data for e2e integration tests (such as cypress), don't confuse
      #       this unit test data setup with the purpose of the controller.

      revision_count_before = Repo.one(from r in Revision, select: count(r.id))
      resource_count_before = Repo.one(from r in Resource, select: count(r.id))

      # Try setting up some test data
      setup_conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{api_key}")
        |> AutomationSetupController.setup(%{
          "create_author" => "true",
          "create_educator" => "true",
          "create_learner" => "true",
          "create_section" => "true",
          "project_archive" => %{
            :path => "./test/oli_web/controllers/api/automation/export_unit_test_project.zip"
          }
        })

      response = Jason.decode!(setup_conn.resp_body)

      # Make sure we got all the properties back that we expected
      %{
        "author" => %{
          "email" => author_email,
          "id" => author_id,
          "password" => author_pass
        },
        "educator" => %{
          "email" => educator_email,
          "id" => educator_id,
          "password" => educator_pass
        },
        "learner" => %{
          "email" => learner_email,
          "id" => learner_id,
          "password" => learner_pass
        },
        "project" => %{
          "id" => project_id,
          "slug" => project_slug,
          "title" => project_title
        },
        "section" => %{
          "id" => section_id,
          "slug" => section_slug
        },
        "success" => true
      } = response

      {:ok, user} = validate_user(author_email, author_pass, :author)
      assert user.name == "Test Author"
      assert user.id == author_id

      {:ok, user} = validate_user(educator_email, educator_pass, :user)
      assert user.name == "Test Educator"
      assert user.id == educator_id
      assert user.email_verified
      assert user.email_confirmed_at

      {:ok, user} = validate_user(learner_email, learner_pass, :user)
      assert user.name == "Test Learner"
      assert user.id == learner_id
      assert user.email_verified
      assert user.email_confirmed_at

      {:ok, project} =
        Oli.Authoring.Course.get_project_by_slug(project_slug) |> trap_nil("Project not found")

      section = Oli.Delivery.Sections.get_section_by(slug: section_slug)
      assert section.id == section_id
      assert section.title == "Automation test section"

      publication = Repo.one!(from p in Publication, where: p.project_id == ^project.id, limit: 1)

      imported_section =
        insert(:section,
          title: "Section imported with the project archive",
          base_project: project
        )

      {:ok, imported_section} =
        Sections.create_section_resources(imported_section, publication)

      assert imported_section.root_section_resource_id

      insert(:section_project_publication,
        section: insert(:section),
        project: project,
        publication: publication
      )

      assert project_title == "Unit Test Project"
      assert project.title == "Unit Test Project"
      assert project_id == project.id
      assert project.slug == project_slug

      # Now, try to use the teardown function to get rid of the data we just set up.
      teardown_conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{api_key}")
        |> Oli.Plugs.ValidateAPIKey.call(&Oli.Interop.validate_for_automation_setup/1)
        |> AutomationSetupController.teardown(%{
          "author_email" => author_email,
          "author_password" => author_pass,
          "educator_email" => educator_email,
          "educator_password" => educator_pass,
          "learner_email" => learner_email,
          "learner_password" => learner_pass,
          "project_slug" => project_slug,
          "section_slug" => section_slug
        })

      response = Jason.decode!(teardown_conn.resp_body)

      # Make sure all items came back as successfully deleted
      %{
        "author_deleted" => %{"success" => true},
        "educator_deleted" => %{"success" => true},
        "learner_deleted" => %{"success" => true},
        "project_deleted" => %{
          "success" => true,
          "queued" => true,
          "job_id" => project_teardown_job_id
        },
        "section_deleted" => %{"success" => true}
      } = response

      assert is_integer(project_teardown_job_id)

      assert_enqueued(
        worker: ProjectTeardownWorker,
        args: %{"project_slug" => project_slug}
      )

      assert %{success: true, queued: true, job_id: ^project_teardown_job_id} =
               AutomationSetup.enqueue_project_teardown(project_slug)

      assert [_job] = all_enqueued(worker: ProjectTeardownWorker)

      # Project cleanup is intentionally asynchronous. In test mode Oban jobs
      # run manually, so the project remains until the worker is performed.
      assert Oli.Authoring.Course.get_project_by_slug(project_slug)

      assert :ok =
               perform_job(ProjectTeardownWorker, %{
                 "project_slug" => project_slug
               })

      refute Accounts.get_author_by_email(author_email)
      refute Accounts.get_author_by_email(author_email)
      refute Accounts.get_independent_user_by_email(educator_email)

      refute Oli.Authoring.Course.get_project_by_slug(project_slug)

      refute Oli.Delivery.Sections.get_section_by(slug: section_slug)
      refute Oli.Delivery.Sections.get_section_by(slug: imported_section.slug)

      refute Repo.exists?(
               from spp in SectionsProjectsPublications,
                 where: spp.project_id == ^project_id or spp.publication_id == ^publication.id
             )

      # Make sure the asynchronous job cleaned up all the records.
      assert revision_count_before == Repo.one(from r in Revision, select: count(r.id))
      assert resource_count_before == Repo.one(from r in Resource, select: count(r.id))
    end

    test "Can not tear down resources not created by automation api", %{
      conn: conn,
      api_key: api_key,
      project: project
    } do
      author = hd(project.authors)

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{api_key}")
        |> Oli.Plugs.ValidateAPIKey.call(&Oli.Interop.validate_for_automation_setup/1)
        |> AutomationSetupController.teardown(%{
          "author_email" => author.email,
          "author_password" => "unknown",
          "educator_email" => nil,
          "educator_password" => nil,
          "learner_email" => nil,
          "learner_password" => nil,
          "project_slug" => project.slug,
          "section_slug" => nil
        })

      response = Jason.decode!(conn.resp_body)

      assert %{
               "author_deleted" => %{"success" => false, "message" => "User not found"},
               "educator_deleted" => %{"success" => false, "message" => "User not specififed"},
               "learner_deleted" => %{"success" => false, "message" => "User not specififed"},
               "project_deleted" => %{
                 "success" => false,
                 "message" => "Can only delete projects with no authors"
               },
               "section_deleted" => %{"success" => false, "message" => "No section slug provided"}
             } = response

      refute_enqueued(
        worker: ProjectTeardownWorker,
        args: %{"project_slug" => project.slug}
      )
    end
  end

  describe "teardown additional_authors" do
    test "deletes every additional author, including one promoted to system admin", %{
      conn: conn,
      api_key: api_key,
      project: project
    } do
      grantor = automation_author(system_role_id: SystemRole.role_id().system_admin)
      target = automation_author()

      {:ok, _} =
        Accounts.admin_update_author(
          target,
          %{"system_role_id" => SystemRole.role_id().system_admin},
          grantor
        )

      response =
        teardown(conn, api_key, project, [
          %{"email" => grantor.email, "password" => @password},
          %{"email" => target.email, "password" => @password}
        ])

      assert response["additional_authors_deleted"] == [
               %{"email" => grantor.email, "success" => true},
               %{"email" => target.email, "success" => true}
             ]

      refute Accounts.get_author_by_email(grantor.email)
      refute Accounts.get_author_by_email(target.email)
    end

    test "refuses authors not created by automation and still deletes the rest", %{
      conn: conn,
      api_key: api_key,
      project: project
    } do
      wrong_password = automation_author()
      not_automation = author_fixture(%{password: @password})
      deletable = automation_author()

      response =
        teardown(conn, api_key, project, [
          %{"email" => wrong_password.email, "password" => "not-the-password"},
          %{"email" => not_automation.email, "password" => @password},
          %{"email" => deletable.email, "password" => @password}
        ])

      assert response["additional_authors_deleted"] == [
               %{
                 "email" => wrong_password.email,
                 "success" => false,
                 "message" => "Credentials didn't match"
               },
               %{
                 "email" => not_automation.email,
                 "success" => false,
                 "message" => "User not found"
               },
               %{"email" => deletable.email, "success" => true}
             ]

      assert Accounts.get_author_by_email(wrong_password.email)
      assert Accounts.get_author_by_email(not_automation.email)
      refute Accounts.get_author_by_email(deletable.email)
    end

    test "deletes additional authors before the project they own", %{
      conn: conn,
      api_key: api_key
    } do
      owner = automation_author()
      project = insert(:project, authors: [owner])

      response =
        teardown(conn, api_key, project, [%{"email" => owner.email, "password" => @password}])

      assert response["additional_authors_deleted"] == [
               %{"email" => owner.email, "success" => true}
             ]

      assert %{"success" => true, "queued" => true} = response["project_deleted"]
    end

    test "rejects an invalid list before deleting anything", %{
      conn: conn,
      api_key: api_key,
      project: project
    } do
      primary = automation_author()
      extra = automation_author()
      valid = %{"email" => extra.email, "password" => @password}

      invalid_lists = [
        "not a list",
        [valid, "not a map"],
        [%{"email" => extra.email}],
        [%{"email" => "", "password" => @password}],
        [valid, %{"email" => String.upcase(extra.email), "password" => @password}],
        [%{"email" => primary.email, "password" => @password}],
        Enum.map(1..6, &%{"email" => "extra#{&1}@example.com", "password" => @password})
      ]

      for additional_authors <- invalid_lists do
        conn =
          conn
          |> authorized(api_key)
          |> AutomationSetupController.teardown(
            teardown_params(project, additional_authors)
            |> Map.merge(%{"author_email" => primary.email, "author_password" => @password})
          )

        assert conn.status == 400, "expected 400 for #{inspect(additional_authors)}"
        assert %{"error" => _} = Jason.decode!(conn.resp_body)
      end

      assert Accounts.get_author_by_email(primary.email)
      assert Accounts.get_author_by_email(extra.email)
    end

    test "omits additional_authors_deleted when the parameter is absent", %{
      conn: conn,
      api_key: api_key,
      project: project
    } do
      response =
        conn
        |> authorized(api_key)
        |> AutomationSetupController.teardown(
          teardown_params(project, nil)
          |> Map.delete("additional_authors")
        )
        |> Map.fetch!(:resp_body)
        |> Jason.decode!()

      assert Map.has_key?(response, "author_deleted")
      refute Map.has_key?(response, "additional_authors_deleted")
    end
  end

  test "the published API spec documents both the teardown body and the teardown response" do
    # Building the full spec warns about other controllers' undocumented actions.
    {spec, _warnings} = ExUnit.CaptureIO.with_io(:stderr, &OliWeb.ApiSpec.spec/0)
    schemas = spec.components.schemas

    assert %{properties: body} = schemas["Automated test data teardown"]
    assert %{properties: response} = schemas["Automated test data teardown response"]
    assert Map.has_key?(body, :additional_authors)
    assert Map.has_key?(response, :additional_authors_deleted)
  end

  test "Invalid API key doesn't work", %{
    conn: conn,
    project: project
  } do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer BAD-API-KEY")
      |> Oli.Plugs.ValidateAPIKey.call(&Oli.Interop.validate_for_automation_setup/1)
      |> AutomationSetupController.teardown(%{
        "author_email" => nil,
        "author_password" => nil,
        "educator_email" => nil,
        "educator_password" => nil,
        "learner_email" => nil,
        "learner_password" => nil,
        "project_slug" => project.slug,
        "section_slug" => nil
      })

    assert conn.status == 403
  end

  defp automation_author(attrs \\ []) do
    author_fixture(
      Enum.into(attrs, %{given_name: "Test", family_name: "Author", password: @password})
    )
  end

  defp authorized(conn, api_key) do
    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("authorization", "Bearer #{api_key}")
    |> Oli.Plugs.ValidateAPIKey.call(&Oli.Interop.validate_for_automation_setup/1)
  end

  defp teardown_params(project, additional_authors) do
    %{
      "author_email" => nil,
      "author_password" => nil,
      "educator_email" => nil,
      "educator_password" => nil,
      "learner_email" => nil,
      "learner_password" => nil,
      "project_slug" => project.slug,
      "section_slug" => nil,
      "additional_authors" => additional_authors
    }
  end

  defp teardown(conn, api_key, project, additional_authors) do
    conn
    |> authorized(api_key)
    |> AutomationSetupController.teardown(teardown_params(project, additional_authors))
    |> Map.fetch!(:resp_body)
    |> Jason.decode!()
  end

  defp validate_user(email, password, user_type) do
    get_by =
      case user_type do
        :author -> &Accounts.get_author_by_email/1
        :user -> &Accounts.get_independent_user_by_email/1
      end

    case get_by.(email) do
      nil ->
        {:error, "User not found"}

      user ->
        case user.__struct__.valid_password?(user, password) do
          true -> {:ok, user}
          false -> {:error, "Credentials didn't match"}
        end
    end
  end

  def create_project(_) do
    {:ok,
     %{
       project: insert(:project)
     }}
  end

  def api_key_seed(%{conn: conn}) do
    # Create an API key we can use to call the api endpoint with
    code = UUID.uuid4()

    {:ok, api_key} = Oli.Interop.create_key(code, "Unit Test Key")
    Oli.Interop.update_key(api_key, %{automation_setup_enabled: true})

    {:ok,
     %{
       conn: conn,
       # Need to send it B64 encoded in the Authorization header, so just doing it here once
       api_key: Base.encode64(code)
     }}
  end
end
