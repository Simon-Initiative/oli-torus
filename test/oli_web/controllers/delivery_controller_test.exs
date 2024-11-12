defmodule OliWeb.DeliveryControllerTest do
  use OliWeb.ConnCase

  alias Oli.Accounts
  alias Oli.Publishing
  alias Oli.Seeder
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  import Mox
  import Oli.Factory

  describe "delivery_controller index" do
    setup [:setup_lti_session]

    test "handles student with no section", %{conn: conn} do
      conn =
        conn
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~
               "Your instructor has not configured this course section. Please check back soon."
    end

    test "handles user with student and instructor roles with no section", %{
      conn: conn
    } do
      conn =
        conn
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Create Course Section</h3>"
    end

    test "handles student with section and research consent form", %{
      conn: conn
    } do
      conn =
        conn
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "Online Consent Form"
    end

    test "handles student with section and no research consent form", %{
      conn: conn,
      section_no_rc: section_no_rc
    } do
      conn =
        conn
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section_no_rc.slug}\">redirected"
    end

    test "handles instructor with no section or linked account", %{
      conn: conn,
      user: _user
    } do
      conn =
        conn
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Create Course Section</h3>"
    end

    test "handles LMS instructor with section and redirects to instructor dashboard", %{
      conn: conn,
      section: section,
      user: user
    } do
      author_id =
        Accounts.list_authors()
        |> hd()
        |> Map.get(:id, 1)

      {:ok, _user} = Accounts.update_user(user, %{author_id: author_id})

      conn =
        conn
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/manage\">redirected"
    end
  end

  describe "delivery_controller link_account" do
    setup [:setup_lti_session]

    test "renders link account form", %{conn: conn} do
      conn =
        conn
        |> get(Routes.delivery_path(conn, :link_account))

      assert html_response(conn, 200) =~ "Link Authoring Account"
    end
  end

  describe "delivery_controller deleted_project" do
    setup [:setup_lti_session]

    test "removes deleted project from available publications", %{
      project: project,
      author: author,
      institution: institution
    } do
      Publishing.publish_project(project, "some changes", author.id)

      Oli.Authoring.Course.update_project(project, %{status: :deleted})

      available_publications = Publishing.available_publications(author, institution)
      assert available_publications == []
    end
  end

  describe "delivery_controller process_link_account_provider" do
    setup [:setup_lti_session]

    test "processes link account for provider", %{conn: conn} do
      conn =
        conn
        |> get(Routes.authoring_delivery_path(conn, :process_link_account_provider, :google))

      assert html_response(conn, 302) =~ "redirect"
    end
  end

  describe "delivery_controller process_link_account_user" do
    setup [:setup_lti_session]

    test "processes link account for user email authentication failure", %{
      conn: conn,
      author: author
    } do
      author_params =
        author
        |> Map.from_struct()
        |> Map.put(:password, "wrong_password")
        |> Map.put(:password_confirmation, "wrong_password")

      conn =
        conn
        |> post(Routes.delivery_path(conn, :process_link_account),
          link_account: author_params
        )

      assert html_response(conn, 200) =~
               "The provided login details did not work. Please verify your credentials, and try again."
    end

    test "processes link account for user email", %{
      conn: conn,
      author: author
    } do
      author_params =
        author
        |> Map.from_struct()
        |> Map.put(:password, "password123")
        |> Map.put(:password_confirmation, "password123")

      conn =
        conn
        |> post(Routes.delivery_path(conn, :process_link_account), link_account: author_params)

      assert html_response(conn, 302) =~ "redirect"
    end

    test "redirect unenrolled user to enrollment page", %{
      conn: conn,
      section: section
    } do
      enrolled_user = user_fixture(%{independent_learner: false})
      other_user = user_fixture(%{independent_learner: false})

      {:ok, _enrollment} =
        Sections.enroll(enrolled_user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> log_in_user(other_user)

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
      enrolled_user = user_fixture(%{independent_learner: false})
      other_user = user_fixture(%{independent_learner: false})

      {:ok, _enrollment} =
        Sections.enroll(enrolled_user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> log_in_user(other_user)

      {:ok, section} = Sections.update_section(section, %{registration_open: false})

      conn = get(conn, Routes.delivery_path(conn, :show_enroll, section.slug))

      assert html_response(conn, 403) =~ "Section Not Available"
    end
  end

  describe "delivery_controller - show_enroll" do
    setup [:setup_lti_session]

    test "blocks LMS users from manually enrollment", %{conn: conn, section: section} do
      # Assert that the user is an LMS user
      assert conn.assigns.current_user.independent_learner == false

      enrollment_path = ~p"/sections/#{section.slug}/enroll"
      conn = get(conn, enrollment_path)
      assert response(conn, 302) =~ "You are being <a href=\"/course\">redirected</a>"
    end

    test "redirect to requested path after login", %{conn: conn, section: section} do
      {:ok, section} = Sections.update_section(section, %{requires_enrollment: true})
      conn = Map.update!(conn, :assigns, &Map.drop(&1, [:current_author, :current_user]))

      enrollment_path = ~p"/sections/#{section.slug}/enroll"

      conn = get(conn, enrollment_path)

      assert_redirect_to_login(conn, section.slug)
    end
  end

  describe "download_course_content_info" do
    setup [:setup_lti_session, :create_project_with_units_and_modules]

    test "downloads the course content when section exists and filters by units", %{
      conn: conn,
      section: section
    } do
      # Filter by units
      conn =
        conn
        |> get(
          Routes.delivery_path(conn, :download_course_content_info, section.slug,
            container_filter_by: :units
          )
        )

      Enum.any?(conn.resp_headers, fn h ->
        h ==
          {"content-disposition", "attachment; filename=\"#{section.slug}_course_content.csv\""}
      end)

      Enum.any?(conn.resp_headers, fn h -> h == {"content-type", "text/csv"} end)

      assert conn.resp_body =~ "Unit Container"
      refute conn.resp_body =~ "Module Container"
      refute conn.resp_body =~ "Loading..."

      assert response(conn, 200)
    end

    test "downloads the course content when section exists and filters by modules", %{
      conn: conn,
      section: section
    } do
      # Filter by modules
      conn =
        conn
        |> get(
          Routes.delivery_path(conn, :download_course_content_info, section.slug,
            container_filter_by: :modules
          )
        )

      refute conn.resp_body =~ "Unit Container"
      assert conn.resp_body =~ "Module Container"
      refute conn.resp_body =~ "Loading..."

      assert response(conn, 200)
    end

    test "Redirects to \"Not found\" page if the section doesn't exist", %{
      conn: conn
    } do
      conn =
        conn
        |> get(Routes.delivery_path(conn, :download_course_content_info, "invalid_section_slug"))

      assert response(conn, 302) =~ "You are being <a href=\"/not_found\">redirected</a>"
    end
  end

  describe "download_students_progress" do
    setup [:setup_lti_session]

    test "downloads the student progress when section exists", %{
      conn: conn,
      section: section
    } do
      conn =
        conn
        |> get(Routes.delivery_path(conn, :download_students_progress, section.slug))

      Enum.any?(conn.resp_headers, fn h ->
        h ==
          {"content-disposition", "attachment; filename=\"#{section.slug}_students.csv\""}
      end)

      Enum.any?(conn.resp_headers, fn h -> h == {"content-type", "text/csv"} end)
      assert response(conn, 200)
    end

    test "Redirects to \"Not found\" page if the section doesn't exist", %{
      conn: conn
    } do
      conn =
        conn
        |> get(Routes.delivery_path(conn, :download_students_progress, "invalid_section_slug"))

      assert response(conn, 302) =~ "You are being <a href=\"/not_found\">redirected</a>"
    end
  end

  describe "download_learning_objectives" do
    setup [:setup_lti_session]

    test "downloads the learning objectives when section exists", %{
      conn: conn,
      section: section
    } do
      conn =
        conn
        |> get(Routes.delivery_path(conn, :download_learning_objectives, section.slug))

      Enum.any?(conn.resp_headers, fn h ->
        h ==
          {"content-disposition", "attachment; filename=\"#{section.slug}_students.csv\""}
      end)

      Enum.any?(conn.resp_headers, fn h -> h == {"content-type", "text/csv"} end)
      assert response(conn, 200)
    end

    test "Redirects to \"Not found\" page if the section doesn't exist", %{
      conn: conn
    } do
      conn =
        conn
        |> get(Routes.delivery_path(conn, :download_learning_objectives, "invalid_section_slug"))

      assert response(conn, 302) =~ "You are being <a href=\"/not_found\">redirected</a>"
    end
  end

  describe "download_quiz_scores" do
    setup [:setup_lti_session]

    test "downloads the quiz scores when section exists", %{
      conn: conn
    } do
      %{section: section} = basic_section(nil)

      conn =
        conn
        |> get(Routes.delivery_path(conn, :download_quiz_scores, section.slug))

      Enum.any?(conn.resp_headers, fn h ->
        h ==
          {"content-disposition", "attachment; filename=\"#{section.slug}_quiz_scores.csv\""}
      end)

      Enum.any?(conn.resp_headers, fn h -> h == {"content-type", "text/csv"} end)
      assert response(conn, 200)
    end

    test "Redirects to \"Not found\" page if the section doesn't exist", %{
      conn: conn
    } do
      conn =
        conn
        |> get(Routes.delivery_path(conn, :download_quiz_scores, "invalid_section_slug"))

      assert response(conn, 302) =~ "You are being <a href=\"/not_found\">redirected</a>"
    end
  end

  describe "independent learner" do
    setup [:setup_independent_learner_session]

    test "shows enroll page if user is not enrolled", %{conn: conn, oaf_section_1: section} do
      conn = get(conn, Routes.delivery_path(conn, :show_enroll, section.slug))

      assert html_response(conn, 200) =~ section.title
      assert html_response(conn, 200) =~ Routes.delivery_path(conn, :process_enroll, section.slug)
    end

    test "enroll redirects to section overview if user is already enrolled", %{
      conn: conn,
      oaf_section_1: section,
      user: user
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, Routes.delivery_path(conn, :show_enroll, section.slug))

      assert html_response(conn, 302) =~
               ~p"/sections/#{section.slug}"
    end

    test "handles open and free user access when date is before start date", %{
      conn: conn,
      oaf_section_1: section
    } do
      enrolled_user = user_fixture(%{independent_learner: false})
      other_user = user_fixture(%{independent_learner: false})

      {:ok, _enrollment} =
        Sections.enroll(enrolled_user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)
        |> log_in_user(other_user)

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

    test "shows enroll page with options for enrolling as guest, signing in, and signing up",
         %{conn: conn} do
      section = insert(:section)
      section_invite = insert(:section_invite, %{section: section})

      conn = get(conn, Routes.delivery_path(conn, :enroll_independent, section_invite.slug))

      assert html_response(conn, 200) =~ section.title
      assert html_response(conn, 200) =~ "Enroll in Course Section"
      assert html_response(conn, 200) =~ "Enroll as Guest"
      assert html_response(conn, 200) =~ "Sign In"
      assert html_response(conn, 200) =~ "Sign Up"
    end

    test "shows enroll page when section is open and free and does not require enrollment",
         %{conn: conn} do
      section = insert(:section, requires_enrollment: false, open_and_free: true)
      section_invite = insert(:section_invite, %{section: section})

      conn = get(conn, Routes.delivery_path(conn, :enroll_independent, section_invite.slug))

      assert html_response(conn, 200) =~ section.title
      assert html_response(conn, 200) =~ "Enroll in Course Section"
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

    test "does not display Sign Up link", %{conn: conn} do
      section = insert(:section)
      section_invite = insert(:section_invite, %{section: section})

      conn = get(conn, Routes.delivery_path(conn, :enroll_independent, section_invite.slug))

      refute html_response(conn, 200) =~ "Sign Up"

      refute html_response(conn, 200) =~
               ~s(<a href="/registration/new?section=#{section.slug}&amp;from_invitation_link%3F=true")
    end
  end

  describe "enroll independent (as guest user)" do
    setup [:guest_conn]

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

    test "redirects to login form with section slug and from_invitation_link? as true as query params",
         %{conn: conn} do
      section = insert(:section, requires_enrollment: true)
      section_invite = insert(:section_invite, %{section: section})

      conn =
        get(
          conn,
          Routes.delivery_path(conn, :enroll_independent, section_invite.slug,
            from_invitation_link?: true
          )
        )

      assert_redirect_to_login(conn, section.slug)
    end

    test "shows enroll view and Sign In link", %{conn: conn} do
      section = insert(:section)
      section_invite = insert(:section_invite, %{section: section})

      conn =
        get(
          conn,
          Routes.delivery_path(conn, :enroll_independent, section_invite.slug,
            from_invitation_link?: true
          )
        )

      assert html_response(conn, 200) =~ "Enroll in Course Section"

      assert html_response(conn, 200) =~
               ~s(<a href="/?section=#{section.slug}&amp;from_invitation_link%3F=true" )
    end

    test "shows enroll view and Sign Up link", %{conn: conn} do
      section = insert(:section)
      section_invite = insert(:section_invite, %{section: section})

      conn =
        get(
          conn,
          Routes.delivery_path(conn, :enroll_independent, section_invite.slug,
            from_invitation_link?: true
          )
        )

      assert html_response(conn, 200) =~ "Sign Up"

      assert html_response(conn, 200) =~
               ~s(<a href="/registration/new?section=#{section.slug}&amp;from_invitation_link%3F=true")
    end
  end

  describe "enroll in the section while logged in" do
    setup [:user_conn]

    test "redirects to overview section screen if section requires enrollment", %{conn: conn} do
      section = insert(:section, requires_enrollment: true)
      conn = get(conn, Routes.delivery_path(conn, :show_enroll, section.slug))

      assert html_response(conn, 200) =~
               "Enroll"

      conn = post(conn, Routes.delivery_path(conn, :process_enroll, section.slug))

      assert html_response(conn, 200) =~
               section.title
    end

    test "redirects to overview section screen if section does not requires enrollment", %{
      conn: conn
    } do
      section = insert(:section, requires_enrollment: false)
      conn = get(conn, Routes.delivery_path(conn, :show_enroll, section.slug))

      assert html_response(conn, 200) =~
               "Enroll"

      conn = post(conn, Routes.delivery_path(conn, :process_enroll, section.slug))

      assert html_response(conn, 200) =~
               section.title
    end
  end

  describe "enroll in the section without being logged in" do
    test "redirects to login screen if section requires enrollment", %{conn: conn} do
      section = insert(:section, requires_enrollment: true)
      conn = get(conn, Routes.delivery_path(conn, :show_enroll, section.slug))

      assert_redirect_to_login(conn, section.slug)

      conn = mock_captcha(conn, section)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Cannot enroll guest users in a course section that requires enrollment"

      assert response(conn, 302) =~
               "<html><body>You are being <a href=\"/session/new?request_path=/sections/#{section.slug}/enroll\">redirected</a>.</body></html>"
    end

    test "redirects to overview section screen if section does not requires enrollment", %{
      conn: conn
    } do
      section = insert(:section, requires_enrollment: false)
      conn = get(conn, Routes.delivery_path(conn, :show_enroll, section.slug))

      assert html_response(conn, 200) =~
               "Enroll as Guest"

      conn = mock_captcha(conn, section)

      assert response(conn, 302) =~
               "<html><body>You are being <a href=\"/sections/#{section.slug}\">redirected</a>.</body></html>"
    end
  end

  defp mock_captcha(conn, section) do
    Oli.Test.MockHTTP
    |> expect(:post, fn "https://www.google.com/recaptcha/api/siteverify",
                        _body,
                        _headers,
                        _opts ->
      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body:
           Jason.encode!(%{
             "success" => true
           })
       }}
    end)

    conn
    |> post(Routes.delivery_path(conn, :process_enroll, section.slug), %{
      "g-recaptcha-response" => "some-valid-capcha-data"
    })
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

    institution_no_rc = insert(:institution, research_consent: :no_form)
    deployment_no_rc = insert(:lti_deployment, institution: institution_no_rc)

    section_no_rc =
      insert(:section, institution: institution_no_rc, lti_1p3_deployment: deployment_no_rc)

    user = user_fixture(%{independent_learner: false})
    student = user_fixture(%{independent_learner: false})
    student_no_section = user_fixture(%{independent_learner: false})
    instructor = user_fixture(%{independent_learner: false})
    instructor_no_section = user_fixture(%{independent_learner: false})
    student_instructor_no_section = user_fixture(%{independent_learner: false})

    %{project: project, publication: publication} = project_fixture(author)

    conn = Plug.Test.init_test_session(conn, lti_session: nil)

    lti_param_ids = %{
      student:
        cache_lti_params(
          %{
            "iss" => registration.issuer,
            "aud" => [registration.client_id],
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
            "aud" => [registration.client_id],
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
      student_no_rc:
        cache_lti_params(
          %{
            "iss" => deployment_no_rc.registration.issuer,
            "aud" => [deployment_no_rc.registration.client_id],
            "sub" => student.sub,
            "exp" => Timex.now() |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix(),
            "https://purl.imsglobal.org/spec/lti/claim/context" => %{
              "id" => section_no_rc.context_id,
              "title" => section_no_rc.title
            },
            "https://purl.imsglobal.org/spec/lti/claim/roles" => [
              "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
            ],
            "https://purl.imsglobal.org/spec/lti/claim/deployment_id" =>
              deployment_no_rc.deployment_id
          },
          student.id
        ),
      instructor_no_rc:
        cache_lti_params(
          %{
            "iss" => deployment_no_rc.registration.issuer,
            "aud" => [deployment_no_rc.registration.client_id],
            "sub" => instructor.sub,
            "exp" => Timex.now() |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix(),
            "https://purl.imsglobal.org/spec/lti/claim/context" => %{
              "id" => section_no_rc.context_id,
              "title" => section_no_rc.title
            },
            "https://purl.imsglobal.org/spec/lti/claim/roles" => [
              "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
            ],
            "https://purl.imsglobal.org/spec/lti/claim/deployment_id" =>
              deployment_no_rc.deployment_id
          },
          instructor.id
        ),
      instructor:
        cache_lti_params(
          %{
            "iss" => registration.issuer,
            "aud" => [registration.client_id],
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
            "aud" => [registration.client_id],
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
            "aud" => [registration.client_id],
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
      |> log_in_user(user)
      |> log_in_author(author)

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
     section_no_rc: section_no_rc}
  end

  defp setup_independent_learner_session(%{conn: conn}) do
    user = user_fixture()

    conn =
      Plug.Test.init_test_session(conn, [])
      |> log_in_user(user)

    map = Seeder.base_project_with_resource4()

    Map.merge(%{conn: conn, user: user}, map)
  end

  defp assert_redirect_to_login(conn, section_slug) do
    enrollment_path = ~p"/sections/#{section_slug}/enroll"

    redirected_path =
      ~p"/?#{[section: section_slug, from_invitation_link?: true, request_path: enrollment_path]}"

    {:safe, link} =
      Phoenix.HTML.Link.link("redirected", to: redirected_path) |> Phoenix.HTML.raw()

    assert html_response(conn, 302) =~ "You are being #{link}."
  end
end
