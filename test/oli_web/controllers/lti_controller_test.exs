defmodule OliWeb.LtiControllerTest do
  use OliWeb.ConnCase

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.Author

  @institution_attrs %{
    country_code: "some country_code",
    institution_email: "some institution_email",
    institution_url: "some institution_url",
    name: "some name",
    timezone: "some timezone",
    consumer_key: "60dc6375-5eeb-4475-8788-fb69e32153b6",
    shared_secret: "6BCF251D1C1181C938BFA91896D4BE9B",
  }

  @sample_lti_request_data %{
    oauth_consumer_key: "60dc6375-5eeb-4475-8788-fb69e32153b6",
    oauth_signature_method: "HMAC-SHA1",
    oauth_timestamp: "1584560550",
    oauth_nonce: "2MkTeXy05t9a3ySh0DwWeOq7iIWYJotNgQLqn1lOdI",
    oauth_version: "1.0",
    context_id: "4dde05e8ca1973bcca9bffc13e1548820eee93a3",
    context_label: "Torus",
    context_title: "Torus Test",
    custom_canvas_api_domain: "canvas.oli.cmu.edu",
    custom_canvas_course_id: "1",
    custom_canvas_enrollment_state: "active",
    custom_canvas_user_id: "14",
    custom_canvas_user_login_id: "exampleuser",
    custom_canvas_workflow_state: "available",
    ext_roles: "urn:lti:instrole:ims/lis/Student,urn:lti:role:ims/lis/Learner,urn:lti:sysrole:ims/lis/User",
    launch_presentation_document_target: "iframe",
    launch_presentation_locale: "en",
    launch_presentation_return_url: "https://canvas.oli.cmu.edu/courses/1/external_content/success/external_tool_redirect",
    lis_person_contact_email_primary: "exampleuser@example.edu",
    lis_person_name_family: "User",
    lis_person_name_full: "Example User",
    lis_person_name_given: "Example",
    lti_message_type: "basic-lti-launch-request",
    lti_version: "LTI-1p0",
    oauth_callback: "about:blank",
    resource_link_id: "82f5cc6b61288d047fc5213547ac8fba4790bffa",
    resource_link_title: "Torus OLI",
    roles: "Learner",
    tool_consumer_info_product_family_code: "canvas",
    tool_consumer_info_version: "cloud",
    tool_consumer_instance_contact_email: "admin@canvas.oli.cmu.edu",
    tool_consumer_instance_guid: "8865aa05b4b79b64a91a86042e43af5ea8ae79eb.localhost:8900",
    tool_consumer_instance_name: "OLI Canvas Admin",
    user_id: "dc86d3e58c1025af0b2cce49205ad2cb1019d546",
    user_image: "https://canvas.oli.cmu.edu/images/messages/avatar-50.png",
    oauth_signature: "39n9SmyZgdk4SbH1QJMrYnzApYo=",
  }

  describe "basic_launch" do
    setup [:create_institution]

    test "creates new user on first time lti request", %{conn: conn, institution: _institution} do
      conn = conn
      |> Map.put(:host, "dcf69df7.ngrok.io")
      |> post(Routes.lti_path(conn, :basic_launch), @sample_lti_request_data)


      assert html_response(conn, 200) =~ "Welcome Example User"
      assert Enum.count(Repo.all(Accounts.User)) == 1
    end

    test "handles invalid lti request", %{conn: conn, institution: _institution} do
      conn = conn
      |> Map.put(:host, "some.invalid.host")
      |> post(Routes.lti_path(conn, :basic_launch), @sample_lti_request_data)

      assert html_response(conn, 200) =~ "LTI Launch Invalid"
      assert Enum.count(Repo.all(Accounts.User)) == 0
    end

    test "uses existing user on subsequent lti requests", %{conn: conn, institution: _institution} do
      # issue first request
      conn
      |> Map.put(:host, "dcf69df7.ngrok.io")
      |> post(Routes.lti_path(conn, :basic_launch), @sample_lti_request_data)

      # issue a second request with same user information
      conn
      |> Map.put(:host, "dcf69df7.ngrok.io")
      |> post(Routes.lti_path(conn, :basic_launch), @sample_lti_request_data)

      # assert that only one user was created through both requests
      assert Enum.count(Repo.all(Accounts.User)) == 1
    end
  end

  defp create_institution(%{ conn: conn  }) do
    {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: Accounts.SystemRole.role_id.author}) |> Repo.insert
    institution_attrs = Map.put(@institution_attrs, :author_id, author.id)
    {:ok, institution} = institution_attrs |> Accounts.create_institution()

    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)

    {:ok, conn: conn, author: author, institution: institution}
  end
end
