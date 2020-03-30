defmodule OliWeb.DeliveryControllerTest do
  use OliWeb.ConnCase

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.Author

  describe "delivery_controller" do
    setup [:setup_session]

    test "index handles student with no section", %{conn: conn} do
      conn = conn
      |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "Your instructor has not configured this course section. Please check back soon."
    end

  end

  @institution_attrs %{
    country_code: "some country_code",
    institution_email: "some institution_email",
    institution_url: "some institution_url",
    name: "some name",
    timezone: "some timezone",
    consumer_key: "60dc6375-5eeb-4475-8788-fb69e32153b6",
    shared_secret: "6BCF251D1C1181C938BFA91896D4BE9B",
  }

  defp setup_session(%{conn: conn}) do
    {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: Accounts.SystemRole.role_id.author}) |> Repo.insert
    institution_attrs = Map.put(@institution_attrs, :author_id, author.id)

    {:ok, institution} = institution_attrs |> Accounts.create_institution()

    lti_params = build_lti_request(url_from_conn(conn), "some-secret", "some-nonce")

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

    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)
      |> put_session(:current_user_id, user.id)
      |> put_session(:lti_params, lti_params)

    {:ok, conn: conn, author: author, institution: institution}
  end
end
