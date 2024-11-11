defmodule OliWeb.Api.AutomationSetupControllerTest do
  use OliWeb.ConnCase
  alias OliWeb.Api.AutomationSetupController
  alias Oli.Resources.Revision
  alias Oli.Accounts
  alias Oli.Repo
  alias Oli.Resources.Resource
  import Oli.Utils
  import Oli.Factory
  import Ecto.Query, warn: false

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

      {:ok, user} = validate_user(learner_email, learner_pass, :user)
      assert user.name == "Test Learner"
      assert user.id == learner_id

      {:ok, project} =
        Oli.Authoring.Course.get_project_by_slug(project_slug) |> trap_nil("Project not found")

      section = Oli.Delivery.Sections.get_section_by(slug: section_slug)
      assert section.id == section_id
      assert section.title == "Automation test section"

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
        "project_deleted" => %{"success" => true},
        "section_deleted" => %{"success" => true}
      } = response

      refute Accounts.get_author_by_email(author_email)
      refute Accounts.get_user_by_email(author_email)
      refute Accounts.get_user_by_email(educator_email)

      refute Oli.Authoring.Course.get_project_by_slug(project_slug)

      refute Oli.Delivery.Sections.get_section_by(slug: section_slug)

      # Make sure we cleaned up all the records
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
    end
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

  defp validate_user(email, password, user_type) do
    get_by =
      case user_type do
        :author -> &Accounts.get_author_by_email/1
        :user -> &Accounts.get_user_by_email/1
      end

    case get_by.(email) do
      nil ->
        {:error, "User not found"}

      user ->
        case user.__struct__.verify_password(user, password) do
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
