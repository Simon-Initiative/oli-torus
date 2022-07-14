defmodule OliWeb.PublisherControllerTest do
  @moduledoc false

  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Inventories

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

    test "renders error when publisher is not available", %{
      conn: conn,
      api_key: api_key
    } do
      unavailable_publisher = insert(:publisher, available_via_api: false)

      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> Base.encode64(api_key))
        |> get(Routes.publisher_path(conn, :show, unavailable_publisher.id))

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

  describe "index" do
    setup [:setup_session]

    test "returns all the existing publishers", %{
      conn: conn,
      api_key: api_key,
      publisher: publisher
    } do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> Base.encode64(api_key))
        |> get(Routes.publisher_path(conn, :index))

      default_publisher = Inventories.default_publisher()

      publishers_response = json_response(conn, 200)["publishers"]

      assert Enum.count(publishers_response) == 2

      assert Enum.find(publishers_response, fn p ->
               p == %{
                 "id" => publisher.id,
                 "name" => publisher.name,
                 "email" => publisher.email,
                 "address" => publisher.address,
                 "main_contact" => publisher.main_contact,
                 "website_url" => publisher.website_url
               }
             end)

      assert Enum.find(publishers_response, fn p ->
               p == %{
                 "id" => default_publisher.id,
                 "name" => default_publisher.name,
                 "email" => default_publisher.email,
                 "address" => default_publisher.address,
                 "main_contact" => default_publisher.main_contact,
                 "website_url" => default_publisher.website_url
               }
             end)
    end

    test "does not return unavailable publishers", %{
      conn: conn,
      api_key: api_key,
      publisher: publisher
    } do
      {:ok, unavailable_publisher} =
        Inventories.update_publisher(publisher, %{available_via_api: false})

      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> Base.encode64(api_key))
        |> get(Routes.publisher_path(conn, :index))

      default_publisher = Inventories.default_publisher()

      publishers_response = json_response(conn, 200)["publishers"]

      assert Enum.count(publishers_response) == 1

      refute Enum.find(publishers_response, fn p ->
               p == %{
                 "id" => unavailable_publisher.id,
                 "name" => unavailable_publisher.name,
                 "email" => unavailable_publisher.email,
                 "address" => unavailable_publisher.address,
                 "main_contact" => unavailable_publisher.main_contact,
                 "website_url" => unavailable_publisher.website_url
               }
             end)

      assert Enum.find(publishers_response, fn p ->
               p == %{
                 "id" => default_publisher.id,
                 "name" => default_publisher.name,
                 "email" => default_publisher.email,
                 "address" => default_publisher.address,
                 "main_contact" => default_publisher.main_contact,
                 "website_url" => default_publisher.website_url
               }
             end)
    end

    test "renders error when api key does not have product scope", %{
      conn: conn,
      api_key: api_key,
      key: key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      Oli.Interop.update_key(key, %{products_enabled: false})

      conn = get(conn, Routes.publisher_path(conn, :index))

      assert response(conn, 401)
    end

    test "renders error when api key has been disabled", %{
      conn: conn,
      api_key: api_key,
      key: key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      Oli.Interop.update_key(key, %{status: :disabled})

      conn = get(conn, Routes.publisher_path(conn, :index))

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
