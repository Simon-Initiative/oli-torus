defmodule OliWeb.PublisherControllerTest do
  @moduledoc false

  use OliWeb.ConnCase

  import Oli.Factory

  describe "show" do
    setup [:setup_session]

    test "returns publisher by id", %{
      conn: conn,
      api_key: api_key,
      publisher: publisher
    } do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> Base.encode64(api_key))
        |> get(Routes.publisher_path(conn, :show, publisher.id))

      assert json_response(conn, 200)["publisher"] == %{
               "id" => publisher.id,
               "name" => publisher.name,
               "email" => publisher.email,
               "address" => publisher.address,
               "main_contact" => publisher.main_contact,
               "website_url" => publisher.website_url
             }
    end

    test "renders error when publisher does not exist", %{
      conn: conn,
      api_key: api_key
    } do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> Base.encode64(api_key))
        |> get(Routes.publisher_path(conn, :show, 0))

      assert response(conn, 404)
    end

    test "renders error when api key does not have product scope", %{
      conn: conn,
      api_key: api_key,
      key: key,
      publisher: publisher
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      Oli.Interop.update_key(key, %{products_enabled: false})

      conn = get(conn, Routes.publisher_path(conn, :show, publisher.id))

      assert response(conn, 401)
    end

    test "renders error when api key has been disabled", %{
      conn: conn,
      api_key: api_key,
      key: key,
      publisher: publisher
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      Oli.Interop.update_key(key, %{status: :disabled})

      conn = get(conn, Routes.publisher_path(conn, :show, publisher.id))

      assert response(conn, 401)
    end
  end

  defp setup_session(%{conn: conn}) do
    publisher = insert(:publisher)

    conn = Plug.Test.init_test_session(conn, lti_session: nil)

    api_key = UUID.uuid4()
    {:ok, key} = Oli.Interop.create_key(api_key, "hint")

    {:ok, conn: conn, publisher: publisher, api_key: api_key, key: key}
  end
end
