defmodule OliWeb.Curriculum.ContainerLiveTest do
  use OliWeb.ConnCase
  alias Oli.Accounts
  alias Oli.Seeder
  alias Oli.Publishing.AuthoringResolver

  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint OliWeb.Endpoint

  describe "container live test" do
    setup [:setup_session]

    test "disconnected and connected mount", %{conn: conn, project: project, map: map} do
      conn = get(conn, "/project/#{project.slug}/curriculum/#{AuthoringResolver.root_container(project.slug).slug}")

      {:ok, view, _} = live(conn)

      # the container should have two pages
      page1 = Map.get(map, :page1)
      page2 = Map.get(map, :page2)

      assert view |> element("##{Integer.to_string(page1.id)}") |> has_element?()
      assert view |> element("##{Integer.to_string(page2.id)}") |> has_element?()

      # click the first item to select it, this would makde the Settings view visible
      view
       |> element("##{Integer.to_string(page1.id)}")
       |> render_click() =~ "Grading Type"

      # delete the selected page
      view
       |> element(".btn-danger")
       |> render_click() =~ "The temperature is: 30℉"

      refute view |> element("##{Integer.to_string(page1.id)}") |> has_element?()
      assert view |> element("##{Integer.to_string(page2.id)}") |> has_element?()

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

    map = Seeder.base_project_with_resource2()

    section = section_fixture(%{
      context_id: "some-context-id",
      project_id: map.project.id,
      publication_id: map.publication.id,
      institution_id: map.institution.id
    })

    conn = Plug.Test.init_test_session(conn, current_author_id: map.author.id)
      |> put_session(:current_user_id, user.id)
      |> put_session(:lti_params, lti_params)

    {:ok,
      conn: conn,
      map: map,
      author: map.author,
      institution: map.institution,
      lti_params: lti_params,
      user: user,
      project: map.project,
      publication: map.publication,
      section: section
    }
  end

end
