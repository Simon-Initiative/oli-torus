defmodule OliWeb.PlatformControllerTest do
  use OliWeb.ConnCase

  alias Oli.Lti_1p3.Platform
  alias Oli.Lti_1p3.Platforms

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

  def fixture(:platform) do
    {:ok, platform} = Platforms.create_platform(@create_attrs)
    platform
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all lti_1p3_platforms", %{conn: conn} do
      conn = get(conn, Routes.platform_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create platform" do
    test "renders platform when data is valid", %{conn: conn} do
      conn = post(conn, Routes.platform_path(conn, :create), platform: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.platform_path(conn, :show, id))

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
      conn = post(conn, Routes.platform_path(conn, :create), platform: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update platform" do
    setup [:create_platform]

    test "renders platform when data is valid", %{conn: conn, platform: %Platform{id: id} = platform} do
      conn = put(conn, Routes.platform_path(conn, :update, platform), platform: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.platform_path(conn, :show, id))

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

    test "renders errors when data is invalid", %{conn: conn, platform: platform} do
      conn = put(conn, Routes.platform_path(conn, :update, platform), platform: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete platform" do
    setup [:create_platform]

    test "deletes chosen platform", %{conn: conn, platform: platform} do
      conn = delete(conn, Routes.platform_path(conn, :delete, platform))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.platform_path(conn, :show, platform))
      end
    end
  end

  defp create_platform(_) do
    platform = fixture(:platform)
    %{platform: platform}
  end
end
