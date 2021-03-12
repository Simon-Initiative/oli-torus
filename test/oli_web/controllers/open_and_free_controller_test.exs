defmodule OliWeb.OpenAndFreeControllerTest do
  use OliWeb.ConnCase

  alias Oli.Delivery

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:open_and_free) do
    {:ok, open_and_free} = Delivery.create_open_and_free(@create_attrs)
    open_and_free
  end

  describe "index" do
    test "lists all open_and_free", %{conn: conn} do
      conn = get(conn, Routes.open_and_free_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Open and free"
    end
  end

  describe "new open_and_free" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.open_and_free_path(conn, :new))
      assert html_response(conn, 200) =~ "New Open and free"
    end
  end

  describe "create open_and_free" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.open_and_free_path(conn, :create), open_and_free: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.open_and_free_path(conn, :show, id)

      conn = get(conn, Routes.open_and_free_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Open and free"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.open_and_free_path(conn, :create), open_and_free: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Open and free"
    end
  end

  describe "edit open_and_free" do
    setup [:create_open_and_free]

    test "renders form for editing chosen open_and_free", %{conn: conn, open_and_free: open_and_free} do
      conn = get(conn, Routes.open_and_free_path(conn, :edit, open_and_free))
      assert html_response(conn, 200) =~ "Edit Open and free"
    end
  end

  describe "update open_and_free" do
    setup [:create_open_and_free]

    test "redirects when data is valid", %{conn: conn, open_and_free: open_and_free} do
      conn = put(conn, Routes.open_and_free_path(conn, :update, open_and_free), open_and_free: @update_attrs)
      assert redirected_to(conn) == Routes.open_and_free_path(conn, :show, open_and_free)

      conn = get(conn, Routes.open_and_free_path(conn, :show, open_and_free))
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, open_and_free: open_and_free} do
      conn = put(conn, Routes.open_and_free_path(conn, :update, open_and_free), open_and_free: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Open and free"
    end
  end

  describe "delete open_and_free" do
    setup [:create_open_and_free]

    test "deletes chosen open_and_free", %{conn: conn, open_and_free: open_and_free} do
      conn = delete(conn, Routes.open_and_free_path(conn, :delete, open_and_free))
      assert redirected_to(conn) == Routes.open_and_free_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.open_and_free_path(conn, :show, open_and_free))
      end
    end
  end

  defp create_open_and_free(_) do
    open_and_free = fixture(:open_and_free)
    %{open_and_free: open_and_free}
  end
end
