defmodule OliWeb.DeliveryControllerTest do
  use OliWeb.ConnCase

  alias Oli.Accounts

  describe "delivery_controller index" do
    setup [:setup_session]

    test "handles student with no section", %{conn: conn} do
      conn = conn
        |> put_session(:lti_1p3_sub, "student-sub")
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "Your instructor has not configured this course section. Please check back soon."
    end

    test "handles user with student and instructor roles with no section", %{conn: conn} do
      conn = conn
        |> put_session(:lti_1p3_sub, "student-instructor-sub")
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Getting Started</h3>"
      assert html_response(conn, 200) =~ "Let's get started by creating a section for your course."
      assert html_response(conn, 200) =~ "Link an Existing Account"
    end

    test "handles student with section", %{conn: conn, user: user, project: project, publication: publication} do
      conn = conn
      |> put_session(:lti_1p3_sub, "student-sub")
      |> post(Routes.delivery_path(conn, :create_section, %{ project_id: project.id, publication_id: publication.id }))

      conn = recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = conn
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 302) =~ "redirected"
    end

    test "handles instructor with no linked account", %{conn: conn, user: _user} do
      conn = conn
        |> put_session(:lti_1p3_sub, "instructor-sub")
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Getting Started</h3>"
      assert html_response(conn, 200) =~ "Let's get started by creating a section for your course."
      assert html_response(conn, 200) =~ "Link an Existing Account"
    end

    test "handles instructor with no section", %{conn: conn, user: user} do
      {:ok, _user} = Accounts.update_user(user, %{author_id: 1})
      conn = conn
        |> put_session(:lti_1p3_sub, "instructor-sub")
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Select a Project</h3>"
    end

    test "handles instructor with section", %{conn: conn, project: project, user: user, publication: publication} do
      {:ok, _user} = Accounts.update_user(user, %{author_id: 1})
      conn = conn
        |> put_session(:lti_1p3_sub, "instructor-sub")
        |> post(Routes.delivery_path(conn, :create_section, %{ project_id: project.id, publication_id: publication.id }))

      conn = recycle(conn)
        |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn = conn
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 302) =~ "redirect"
    end

  end

  defp setup_session(%{conn: conn}) do
    author = author_fixture()
    institution = institution_fixture(%{ author_id: author.id })
    user = user_fixture(%{institution_id: institution.id})

    %{ project: project, publication: publication } = project_fixture(author)

    Oli.Lti_1p3.cache_lti_params!("student-sub", %{
      "sub" => "student-sub",
      "exp" => Timex.now |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix,
      "https://purl.imsglobal.org/spec/lti/claim/context" => %{
        "id" => "some-context-id",
        "title" => "some-title",
      },
      "https://purl.imsglobal.org/spec/lti/claim/roles" => [
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
      ],
    })
    Oli.Lti_1p3.cache_lti_params!("instructor-sub", %{
      "sub" => "instructor-sub",
      "exp" => Timex.now |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix,
      "https://purl.imsglobal.org/spec/lti/claim/context" => %{
        "id" => "some-context-id",
        "title" => "some-title",
      },
      "https://purl.imsglobal.org/spec/lti/claim/roles" => [
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor",
      ],
    })
    Oli.Lti_1p3.cache_lti_params!("student-instructor-sub", %{
      "sub" => "instructor-sub",
      "exp" => Timex.now |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix,
      "https://purl.imsglobal.org/spec/lti/claim/context" => %{
        "id" => "some-context-id",
        "title" => "some-title",
      },
      "https://purl.imsglobal.org/spec/lti/claim/roles" => [
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor",
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
      ],
    })

    conn = Plug.Test.init_test_session(conn, lti_1p3_sub: "student-sub")
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      |> Pow.Plug.assign_current_user(author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok,
      conn: conn,
      author: author,
      institution: institution,
      user: user,
      project: project,
      publication: publication
    }
  end
end
