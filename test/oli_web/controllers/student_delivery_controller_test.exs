defmodule OliWeb.StudentDeliveryControllerTest do
  use OliWeb.ConnCase
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionRoles
  alias Oli.Accounts

  describe "delivery_controller index" do
    setup [:setup_session]

    test "handles student access by an enrolled student", %{conn: conn, user: user, section: section} do

      Sections.enroll(user.id, section.id, SectionRoles.get_by_type("student").id)

      conn = conn
      |> get(Routes.student_delivery_path(conn, :index, section.context_id))

      assert html_response(conn, 200) =~ "Student View"
    end

    test "handles student access who is not enrolled", %{conn: conn, section: section} do
      conn = conn
      |> get(Routes.student_delivery_path(conn, :index, section.context_id))

      assert html_response(conn, 200) =~ "Not authorized"
    end

    test "handles student access by an instructor", %{conn: conn, user: user, section: section} do

      Sections.enroll(user.id, section.id, SectionRoles.get_by_type("instructor"))

      conn = conn
      |> get(Routes.student_delivery_path(conn, :index, section.context_id))

      assert html_response(conn, 200) =~ "Not authorized"
    end



  end

  defp setup_session(%{conn: conn}) do
    author = author_fixture()
    institution = institution_fixture(%{ author_id: author.id })
    lti_params = build_lti_request(url_from_conn(conn), "some-secret")

    {:ok, lti_tool_consumer} = Accounts.insert_or_update_lti_tool_consumer(%{
      info_product_family_code: lti_params["tool_consumer_info_product_family_code"],
      info_version: lti_params["tool_consumer_info_version"],
      instance_contact_email: lti_params["tool_consumer_instance_contact_email"],
      instance_guid: lti_params["tool_consumer_instance_guid"],
      instance_name: lti_params["tool_consumer_instance_name"],
      institution_id: institution.id,
    })
    {:ok, user } = Accounts.insert_or_update_user(%{
      email: lti_params["lis_person_contact_email_primary"],
      first_name: lti_params["lis_person_name_given"],
      last_name: lti_params["lis_person_name_family"],
      user_id: lti_params["user_id"],
      user_image: lti_params["user_image"],
      roles: lti_params["roles"],
      lti_tool_consumer_id: lti_tool_consumer.id,
      institution_id: institution.id,
    })

    %{ project: project, publication: publication } = project_fixture(author)

    section = section_fixture(%{
      context_id: "some-context-id",
      project_id: project.id,
      publication_id: publication.id,
      institution_id: institution.id
    })

    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)
      |> put_session(:current_user_id, user.id)
      |> put_session(:lti_params, lti_params)

    {:ok,
      conn: conn,
      author: author,
      institution: institution,
      lti_params: lti_params,
      user: user,
      project: project,
      publication: publication,
      section: section
    }
  end
end
