defmodule OliWeb.Api.PlatformInstanceControllerTest do
  use OliWeb.ConnCase

  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance
  alias Oli.Lti_1p3.PlatformInstances

  @create_attrs %{
    client_id: "some client_id",
    custom_params: "some custom_params",
    description: "some description",
    keyset_url: "some keyset_url",
    login_url: "some login_url",
    name: "some name",
    redirect_uris: "some redirect_uris",
    target_link_uri: "some target_link_uri"
  }
  @update_attrs %{
    client_id: "some updated client_id",
    custom_params: "some updated custom_params",
    description: "some updated description",
    keyset_url: "some updated keyset_url",
    login_url: "some updated login_url",
    name: "some updated name",
    redirect_uris: "some updated redirect_uris",
    target_link_uri: "some updated target_link_uri"
  }
  @invalid_attrs %{client_id: nil, custom_params: nil, description: nil, keyset_url: nil, login_url: nil, name: nil, redirect_uris: nil, target_link_uri: nil}

  def fixture(:platform_instance) do
    {:ok, platform_instance} = PlatformInstances.create_platform_instance(@create_attrs)
    platform_instance
  end

  def accept_json(%{conn: conn}) do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  setup [:author_project_conn, :accept_json]

  describe "index" do
    test "lists all lti_1p3_platform_instances", %{conn: conn} do
      conn = get(conn, Routes.api_platform_instance_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create platform_instance" do
    test "renders platform_instance when data is valid", %{conn: conn, author: author} do
      conn = post(conn, Routes.api_platform_instance_path(conn, :create), platform_instance: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_author_session(conn, author)

      conn = get(conn, Routes.api_platform_instance_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "client_id" => "some client_id",
               "custom_params" => "some custom_params",
               "description" => "some description",
               "keyset_url" => "some keyset_url",
               "login_url" => "some login_url",
               "name" => "some name",
               "redirect_uris" => "some redirect_uris",
               "target_link_uri" => "some target_link_uri"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.api_platform_instance_path(conn, :create), platform_instance: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update platform_instance" do
    setup [:create_platform_instance]

    test "renders platform_instance when data is valid", %{conn: conn, author: author, platform_instance: %PlatformInstance{id: id} = platform_instance} do
      conn = put(conn, Routes.api_platform_instance_path(conn, :update, platform_instance), platform_instance: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_author_session(conn, author)

      conn = get(conn, Routes.api_platform_instance_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "client_id" => "some updated client_id",
               "custom_params" => "some updated custom_params",
               "description" => "some updated description",
               "keyset_url" => "some updated keyset_url",
               "login_url" => "some updated login_url",
               "name" => "some updated name",
               "redirect_uris" => "some updated redirect_uris",
               "target_link_uri" => "some updated target_link_uri"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, platform_instance: platform_instance} do
      conn = put(conn, Routes.api_platform_instance_path(conn, :update, platform_instance), platform_instance: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete platform_instance" do
    setup [:create_platform_instance]

    test "deletes chosen platform_instance", %{conn: conn, author: author, platform_instance: platform_instance} do
      conn = delete(conn, Routes.api_platform_instance_path(conn, :delete, platform_instance))
      assert response(conn, 204)

      conn = recycle_author_session(conn, author)

      assert_error_sent 404, fn ->
        get(conn, Routes.api_platform_instance_path(conn, :show, platform_instance))
      end
    end
  end

  defp create_platform_instance(_) do
    platform_instance = fixture(:platform_instance)
    %{platform_instance: platform_instance}
  end
end
