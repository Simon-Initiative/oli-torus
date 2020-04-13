defmodule OliWeb.LtiControllerTest do
  use OliWeb.ConnCase

  alias Oli.Repo
  alias Oli.Accounts

  describe "basic_launch" do
    setup [:create_institution]

    test "creates new user on first time lti request", %{conn: conn, institution: _institution} do
      conn = conn
      |> Map.put(:host, "www.example.com")
      |> post(Routes.lti_path(conn, :basic_launch), build_lti_request(url_from_conn(conn), "test-secret"))


      assert redirected_to(conn, :found) =~ "/course"
      assert Enum.count(Repo.all(Accounts.User)) == 1
    end

    test "handles invalid lti request", %{conn: conn, institution: _institution} do
      conn = conn
      |> Map.put(:host, "some.invalid.host")
      |> post(Routes.lti_path(conn, :basic_launch), build_lti_request(url_from_conn(conn), "test-secret"))

      assert html_response(conn, 200) =~ "LTI Connection is Invalid"
      assert Enum.Empty?(Repo.all(Accounts.User))
    end

    test "uses existing user on subsequent lti requests", %{conn: conn, institution: _institution} do
      # issue first request
      conn = conn
      |> Map.put(:host, "www.example.com")
      |> post(Routes.lti_path(conn, :basic_launch), build_lti_request(url_from_conn(conn), "test-secret"))
      assert redirected_to(conn, :found) =~ "/course"

      # issue a second request with same user information
      conn = conn
      |> Map.put(:host, "www.example.com")
      |> post(Routes.lti_path(conn, :basic_launch), build_lti_request(url_from_conn(conn), "test-secret"))
      assert redirected_to(conn, :found) =~ "/course"

      # assert that only one user was created through both requests
      assert Enum.count(Repo.all(Accounts.User)) == 1
    end

    test "fails on duplicate nonce", %{conn: conn, institution: _institution} do
      # issue first request
      conn = conn
      |> Map.put(:host, "www.example.com")
      |> post(Routes.lti_path(conn, :basic_launch), build_lti_request(url_from_conn(conn), "test-secret", %{"oauth_nonce" => "some-duplicate-nonce"}))
      assert redirected_to(conn, :found) =~ "/course"

      # issue a second request with same user information
      conn = conn
      |> Map.put(:host, "www.example.com")
      |> post(Routes.lti_path(conn, :basic_launch), build_lti_request(url_from_conn(conn), "test-secret", %{"oauth_nonce" => "some-duplicate-nonce"}))
      assert html_response(conn, 200) =~ "Invalid OAuth - Duplicate nonce"
    end
  end

  defp create_institution(%{ conn: conn  }) do
    author = author_fixture()
    institution = institution_fixture(%{ author_id: author.id })

    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)

    {:ok, conn: conn, author: author, institution: institution}
  end
end
