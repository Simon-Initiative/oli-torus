defmodule OliWeb.PlatformInstanceControllerTest do
  use OliWeb.ConnCase

  alias Oli.OliWeb

  @create_attrs %{client_id: "some client_id", custom_params: "some custom_params", description: "some description", keyset_url: "some keyset_url", login_url: "some login_url", name: "some name", redirect_uris: "some redirect_uris", target_link_uri: "some target_link_uri"}
  @update_attrs %{client_id: "some updated client_id", custom_params: "some updated custom_params", description: "some updated description", keyset_url: "some updated keyset_url", login_url: "some updated login_url", name: "some updated name", redirect_uris: "some updated redirect_uris", target_link_uri: "some updated target_link_uri"}
  @invalid_attrs %{client_id: nil, custom_params: nil, description: nil, keyset_url: nil, login_url: nil, name: nil, redirect_uris: nil, target_link_uri: nil}

  def fixture(:platform_instance) do
    {:ok, platform_instance} = OliWeb.create_platform_instance(@create_attrs)
    platform_instance
  end

  describe "index" do
    test "lists all lti_1p3_platform_instances", %{conn: conn} do
      conn = get(conn, Routes.platform_instance_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Lti 1p3 platform instances"
    end
  end

  describe "new platform_instance" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.platform_instance_path(conn, :new))
      assert html_response(conn, 200) =~ "New Platform instance"
    end
  end

  describe "create platform_instance" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.platform_instance_path(conn, :create), platform_instance: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.platform_instance_path(conn, :show, id)

      conn = get(conn, Routes.platform_instance_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Platform instance"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.platform_instance_path(conn, :create), platform_instance: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Platform instance"
    end
  end

  describe "edit platform_instance" do
    setup [:create_platform_instance]

    test "renders form for editing chosen platform_instance", %{conn: conn, platform_instance: platform_instance} do
      conn = get(conn, Routes.platform_instance_path(conn, :edit, platform_instance))
      assert html_response(conn, 200) =~ "Edit Platform instance"
    end
  end

  describe "update platform_instance" do
    setup [:create_platform_instance]

    test "redirects when data is valid", %{conn: conn, platform_instance: platform_instance} do
      conn = put(conn, Routes.platform_instance_path(conn, :update, platform_instance), platform_instance: @update_attrs)
      assert redirected_to(conn) == Routes.platform_instance_path(conn, :show, platform_instance)

      conn = get(conn, Routes.platform_instance_path(conn, :show, platform_instance))
      assert html_response(conn, 200) =~ "some updated client_id"
    end

    test "renders errors when data is invalid", %{conn: conn, platform_instance: platform_instance} do
      conn = put(conn, Routes.platform_instance_path(conn, :update, platform_instance), platform_instance: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Platform instance"
    end
  end

  describe "delete platform_instance" do
    setup [:create_platform_instance]

    test "deletes chosen platform_instance", %{conn: conn, platform_instance: platform_instance} do
      conn = delete(conn, Routes.platform_instance_path(conn, :delete, platform_instance))
      assert redirected_to(conn) == Routes.platform_instance_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.platform_instance_path(conn, :show, platform_instance))
      end
    end
  end

  defp create_platform_instance(_) do
    platform_instance = fixture(:platform_instance)
    %{platform_instance: platform_instance}
  end
end
