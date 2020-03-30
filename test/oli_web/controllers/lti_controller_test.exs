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

  describe "basic_launch" do
    setup [:create_institution]

    test "creates new user on first time lti request", %{conn: conn, institution: _institution} do
      conn = conn
      |> Map.put(:host, "www.example.com")
      |> post(Routes.lti_path(conn, :basic_launch), build_lti_request(url_from_conn(conn), "6BCF251D1C1181C938BFA91896D4BE9B", "2MkTeXy05t9a3ySh0DwWeOq7iIWYJotNgQLqn1lOdI"))


      assert redirected_to(conn, :found) =~ "/course"
      assert Enum.count(Repo.all(Accounts.User)) == 1
    end

    test "handles invalid lti request", %{conn: conn, institution: _institution} do
      conn = conn
      |> Map.put(:host, "some.invalid.host")
      |> post(Routes.lti_path(conn, :basic_launch), build_lti_request(url_from_conn(conn), "6BCF251D1C1181C938BFA91896D4BE9B", "2MkTeXy05t9a3ySh0DwWeOq7iIWYJotNgQLqn1lOdI"))

      assert html_response(conn, 200) =~ "LTI Connection is Invalid"
      assert Enum.count(Repo.all(Accounts.User)) == 0
    end

    test "uses existing user on subsequent lti requests", %{conn: conn, institution: _institution} do
      # issue first request
      conn = conn
      |> Map.put(:host, "www.example.com")
      |> post(Routes.lti_path(conn, :basic_launch), build_lti_request(url_from_conn(conn), "6BCF251D1C1181C938BFA91896D4BE9B", "2MkTeXy05t9a3ySh0DwWeOq7iIWYJotNgQLqn1lOdI"))
      assert redirected_to(conn, :found) =~ "/course"

      # issue a second request with same user information
      conn = conn
      |> Map.put(:host, "www.example.com")
      |> post(Routes.lti_path(conn, :basic_launch), build_lti_request(url_from_conn(conn), "6BCF251D1C1181C938BFA91896D4BE9B", "yggRHFN54fEXbhiVnFZNtXYZpeeE8d9uVmUeFpVho"))
      assert redirected_to(conn, :found) =~ "/course"

      # assert that only one user was created through both requests
      assert Enum.count(Repo.all(Accounts.User)) == 1
    end

    test "fails on duplicate nonce", %{conn: conn, institution: _institution} do
      # issue first request
      conn = conn
      |> Map.put(:host, "www.example.com")
      |> post(Routes.lti_path(conn, :basic_launch), build_lti_request(url_from_conn(conn), "6BCF251D1C1181C938BFA91896D4BE9B", "2MkTeXy05t9a3ySh0DwWeOq7iIWYJotNgQLqn1lOdI"))
      assert redirected_to(conn, :found) =~ "/course"

      # issue a second request with same user information
      conn = conn
      |> Map.put(:host, "www.example.com")
      |> post(Routes.lti_path(conn, :basic_launch), build_lti_request(url_from_conn(conn), "6BCF251D1C1181C938BFA91896D4BE9B", "2MkTeXy05t9a3ySh0DwWeOq7iIWYJotNgQLqn1lOdI"))
      assert html_response(conn, 200) =~ "Invalid OAuth - Duplicate nonce"
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
