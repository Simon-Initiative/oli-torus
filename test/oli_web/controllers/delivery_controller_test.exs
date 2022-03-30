defmodule OliWeb.DeliveryControllerTest do
  use OliWeb.ConnCase

  alias Oli.Accounts
  alias OliWeb.Common.LtiSession
  alias Oli.Publishing
  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  import Oli.Factory

  describe "delivery_controller index" do
    setup [:setup_lti_session]

    test "handles student with no section", %{conn: conn, lti_param_ids: lti_param_ids} do
      conn =
        conn
        |> LtiSession.put_session_lti_params(lti_param_ids.student_no_section)
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~
               "Your instructor has not configured this course section. Please check back soon."
    end

    test "handles user with student and instructor roles with no section", %{
      conn: conn,
      lti_param_ids: lti_param_ids
    } do
      conn =
        conn
        |> LtiSession.put_session_lti_params(lti_param_ids.student_instructor_no_section)
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Create Course Section</h3>"
    end

    test "handles student with section", %{conn: conn, lti_param_ids: lti_param_ids} do
      conn =
        conn
        |> LtiSession.put_session_lti_params(lti_param_ids.student)
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "Online Consent Form"
    end

    test "handles instructor with no section or linked account", %{
      conn: conn,
      lti_param_ids: lti_param_ids,
      user: _user
    } do
      conn =
        conn
        |> LtiSession.put_session_lti_params(lti_param_ids.instructor_no_section)
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Create Course Section</h3>"
    end

    test "handles instructor with section", %{
      conn: conn,
      lti_param_ids: lti_param_ids,
      user: user
    } do
      {:ok, _user} = Accounts.update_user(user, %{author_id: 1})

      conn =
        conn
        |> LtiSession.put_session_lti_params(lti_param_ids.instructor)
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "Online Consent Form"
    end

    test "handles instructor create section", %{
      conn: conn,
      lti_param_ids: lti_param_ids,
      user: user,
      publication: publication
    } do
      {:ok, _user} = Accounts.update_user(user, %{author_id: 1})

      conn =
        conn
        |> LtiSession.put_session_lti_params(lti_param_ids.instructor_no_section)
        |> post(
          Routes.delivery_path(conn, :create_section, %{
            source_id: "publication:#{publication.id}"
          })
        )

      assert html_response(conn, 302) =~ "redirect"
    end
  end

  describe "delivery_controller link_account" do
    setup [:setup_lti_session]

    test "renders link account form", %{conn: conn, lti_param_ids: lti_param_ids} do
      conn =
        conn
        |> LtiSession.put_session_lti_params(lti_param_ids.instructor)
        |> get(Routes.delivery_path(conn, :link_account))

      assert html_response(conn, 200) =~ "Link Existing Account"
    end
  end

  describe "delivery_controller deleted_project" do
    setup [:setup_lti_session]

    test "removes deleted project from available publications", %{
      conn: conn,
      project: project,
      author: author,
      institution: institution
    } do
      Publishing.publish_project(project, "some changes")

      delete(conn, Routes.project_path(conn, :delete, project), title: project.title)

      available_publications = Publishing.available_publications(author, institution)
      assert available_publications == []
    end
  end

  describe "delivery_controller process_link_account_provider" do
    setup [:setup_lti_session]

    test "processes link account for provider", %{conn: conn, lti_param_ids: lti_param_ids} do
      conn =
        conn
        |> LtiSession.put_session_lti_params(lti_param_ids.instructor)
        |> get(Routes.authoring_delivery_path(conn, :process_link_account_provider, :google))

      assert html_response(conn, 302) =~ "redirect"
    end
  end

  describe "delivery_controller process_link_account_user" do
    setup [:setup_lti_session]

    test "processes link account for user email authentication failure", %{
      conn: conn,
      lti_param_ids: lti_param_ids,
      author: author
    } do
      author_params =
        author
        |> Map.from_struct()
        |> Map.put(:password, "wrong_password")
        |> Map.put(:password_confirmation, "wrong_password")

      conn =
        conn
        |> LtiSession.put_session_lti_params(lti_param_ids.instructor)
        |> post(Routes.delivery_path(conn, :process_link_account_user),
          user: author_params
        )

      assert html_response(conn, 200) =~
               "The provided login details did not work. Please verify your credentials, and try again."
    end

    test "processes link account for user email", %{
      conn: conn,
      lti_param_ids: lti_param_ids,
      author: author
    } do
      author_params =
        author
        |> Map.from_struct()
        |> Map.put(:password, "password123")
        |> Map.put(:password_confirmation, "password123")

      conn =
        conn
        |> LtiSession.put_session_lti_params(lti_param_ids.instructor)
        |> post(Routes.delivery_path(conn, :process_link_account_user), user: author_params)

      assert html_response(conn, 302) =~ "redirect"
    end

    test "redirect unenrolled user to enrollment page", %{
      conn: conn,
      section: section
    } do
      enrolled_user = user_fixture()
      other_user = user_fixture()

      {:ok, _enrollment} =
        Sections.enroll(enrolled_user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> Pow.Plug.assign_current_user(other_user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      {:ok, section} =
        Sections.update_section(section, %{
          end_date: Timex.now() |> Timex.subtract(Timex.Duration.from_days(1))
        })

      conn = get(conn, Routes.delivery_path(conn, :show_enroll, section.slug))

      assert html_response(conn, 403) =~ "Section Has Concluded"
    end

    test "handles open and free user access when registration is closed", %{
      conn: conn,
      section: section
    } do
      enrolled_user = user_fixture()
      other_user = user_fixture()

      {:ok, _enrollment} =
        Sections.enroll(enrolled_user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> Pow.Plug.assign_current_user(other_user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      {:ok, section} = Sections.update_section(section, %{registration_open: false})

      conn = get(conn, Routes.delivery_path(conn, :show_enroll, section.slug))

      assert html_response(conn, 403) =~ "Section Not Available"
    end
  end

  describe "open and free" do
    setup [:setup_open_and_free_session]

    test "shows enroll page if user is not enrolled", %{conn: conn, oaf_section_1: section} do
      conn = get(conn, Routes.delivery_path(conn, :show_enroll, section.slug))

      assert html_response(conn, 200) =~ "<h5 class=\"card-title\">#{section.title}</h5>"
      assert html_response(conn, 200) =~ Routes.delivery_path(conn, :process_enroll, section.slug)
    end

    test "enroll redirects to section overview if user is already enrolled", %{
      conn: conn,
      oaf_section_1: section,
      user: user
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.delivery_path(conn, :show_enroll, section.slug))

      assert html_response(conn, 302) =~ Routes.page_delivery_path(conn, :index, section.slug)
    end

    test "handles open and free user access when date is before start date", %{
      conn: conn,
      oaf_section_1: section
    } do
      enrolled_user = user_fixture()
      other_user = user_fixture()

      {:ok, _enrollment} =
        Sections.enroll(enrolled_user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> Pow.Plug.assign_current_user(other_user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      {:ok, section} =
        Sections.update_section(section, %{
          start_date: Timex.now() |> Timex.add(Timex.Duration.from_days(1))
        })

      conn = get(conn, Routes.delivery_path(conn, :show_enroll, section.slug))

      assert html_response(conn, 403) =~ "Section Has Not Started"
    end
  end

  @moduletag :capture_log
  describe "enroll independent (without user logged in)" do
    test "redirects to invalid join when invite slug does not exist", %{conn: conn} do
      conn = get(conn, Routes.delivery_path(conn, :enroll_independent, "some_invitation"))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/join/invalid\">redirected"
    end

    test "redirects to login form with section slug as query param", %{conn: conn} do
      section = insert(:section)
      section_invite = insert(:section_invite, %{section: section})

      conn = get(conn, Routes.delivery_path(conn, :enroll_independent, section_invite.slug))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/session/new?request_path=%2Fsections%2Fjoin%2F#{section_invite.slug}&amp;section=#{section.slug}\">redirected"
    end
  end

  @moduletag :capture_log
  describe "enroll independent (with user logged in)" do
    setup [:user_conn]

    test "redirects to invalid join view", %{conn: conn} do
      section = insert(:section)
      date_expires = DateTime.add(DateTime.utc_now(), -3600)
      section_invite = insert(:section_invite, %{section: section, date_expires: date_expires})

      conn = get(conn, Routes.delivery_path(conn, :enroll_independent, section_invite.slug))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/join/invalid\">redirected"
    end

    test "redirects to section unavailable when section has yet to be started", %{conn: conn} do
      section = insert(:section)
      later = DateTime.add(DateTime.utc_now(), 100_000)

      {:ok, section} = Oli.Delivery.Sections.update_section(section, %{start_date: later})
      assert {:unavailable, :before_start_date} == Oli.Delivery.Sections.available?(section)

      section_invite = insert(:section_invite, %{section: section})
      refute Oli.Delivery.Sections.SectionInvites.link_expired?(section_invite)

      conn = get(conn, Routes.delivery_path(conn, :enroll_independent, section_invite.slug))

      assert html_response(conn, 403) =~
               "You are attempting to access a section before its scheduled start date."
    end

    test "redirects to section unavailable when section has already ended", %{conn: conn} do
      section = insert(:section)
      in_the_past = DateTime.add(DateTime.utc_now(), -100_000)

      {:ok, section} = Oli.Delivery.Sections.update_section(section, %{end_date: in_the_past})
      assert {:unavailable, :after_end_date} == Oli.Delivery.Sections.available?(section)

      section_invite = insert(:section_invite, %{section: section})
      refute Oli.Delivery.Sections.SectionInvites.link_expired?(section_invite)

      conn = get(conn, Routes.delivery_path(conn, :enroll_independent, section_invite.slug))

      assert html_response(conn, 403) =~
               "You are attempting to access a section after its scheduled end date."
    end

    test "shows enroll view", %{conn: conn} do
      section = insert(:section)
      section_invite = insert(:section_invite, %{section: section})

      conn = get(conn, Routes.delivery_path(conn, :enroll_independent, section_invite.slug))

      assert html_response(conn, 200) =~ "Enroll in Course Section"
    end
  end

  defp setup_lti_session(%{conn: conn}) do
    author =
      author_fixture(%{
        password: "password123",
        password_confirmation: "password123"
      })

    %{project: project, institution: institution} = Oli.Seeder.base_project_with_resource(author)

    tool_jwk = jwk_fixture()

    registration = registration_fixture(%{tool_jwk_id: tool_jwk.id})

    deployment =
      deployment_fixture(%{institution_id: institution.id, registration_id: registration.id})

    section =
      section_fixture(%{
        institution_id: institution.id,
        lti_1p3_deployment_id: deployment.id,
        base_project_id: project.id
      })

    user = user_fixture()
    student = user_fixture()
    student_no_section = user_fixture()
    instructor = user_fixture()
    instructor_no_section = user_fixture()
    student_instructor_no_section = user_fixture()

    %{project: project, publication: publication} = project_fixture(author)

    conn = Plug.Test.init_test_session(conn, lti_session: nil)

    lti_param_ids = %{
      student:
        cache_lti_params(
          %{
            "iss" => registration.issuer,
            "aud" => registration.client_id,
            "sub" => student.sub,
            "exp" => Timex.now() |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix(),
            "https://purl.imsglobal.org/spec/lti/claim/context" => %{
              "id" => section.context_id,
              "title" => section.title
            },
            "https://purl.imsglobal.org/spec/lti/claim/roles" => [
              "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
            ],
            "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id
          },
          student.id
        ),
      student_no_section:
        cache_lti_params(
          %{
            "iss" => registration.issuer,
            "aud" => registration.client_id,
            "sub" => student_no_section.sub,
            "exp" => Timex.now() |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix(),
            "https://purl.imsglobal.org/spec/lti/claim/context" => %{
              "id" => "some-new-context-id",
              "title" => "some new title"
            },
            "https://purl.imsglobal.org/spec/lti/claim/roles" => [
              "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
            ],
            "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id
          },
          student_no_section.id
        ),
      instructor:
        cache_lti_params(
          %{
            "iss" => registration.issuer,
            "aud" => registration.client_id,
            "sub" => instructor.sub,
            "exp" => Timex.now() |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix(),
            "https://purl.imsglobal.org/spec/lti/claim/context" => %{
              "id" => section.context_id,
              "title" => section.title
            },
            "https://purl.imsglobal.org/spec/lti/claim/roles" => [
              "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
            ],
            "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id
          },
          instructor.id
        ),
      instructor_no_section:
        cache_lti_params(
          %{
            "iss" => registration.issuer,
            "aud" => registration.client_id,
            "sub" => instructor_no_section.sub,
            "exp" => Timex.now() |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix(),
            "https://purl.imsglobal.org/spec/lti/claim/context" => %{
              "id" => "some-new-context-id",
              "title" => "some new title"
            },
            "https://purl.imsglobal.org/spec/lti/claim/roles" => [
              "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
            ],
            "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id
          },
          instructor_no_section.id
        ),
      student_instructor_no_section:
        cache_lti_params(
          %{
            "iss" => registration.issuer,
            "aud" => registration.client_id,
            "sub" => student_instructor_no_section.sub,
            "exp" => Timex.now() |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix(),
            "https://purl.imsglobal.org/spec/lti/claim/context" => %{
              "id" => "some-new-context-id",
              "title" => "some new title"
            },
            "https://purl.imsglobal.org/spec/lti/claim/roles" => [
              "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor",
              "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
            ],
            "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id
          },
          student_instructor_no_section.id
        )
    }

    conn =
      conn
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      |> Pow.Plug.assign_current_user(author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok,
     conn: conn,
     author: author,
     institution: institution,
     section: section,
     user: user,
     student: student,
     student_no_section: student_no_section,
     instructor: instructor,
     instructor_no_section: instructor_no_section,
     student_instructor_no_section: student_instructor_no_section,
     project: project,
     publication: publication,
     lti_param_ids: lti_param_ids}
  end

  defp setup_open_and_free_session(%{conn: conn}) do
    user = user_fixture()

    conn =
      Plug.Test.init_test_session(conn, [])
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

    map = Seeder.base_project_with_resource4()

    Map.merge(%{conn: conn, user: user}, map)
  end
end
