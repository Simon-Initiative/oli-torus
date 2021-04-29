defmodule OliWeb.BrandControllerTest do
  use OliWeb.ConnCase

  alias Oli.Branding

  @create_attrs %{favicons: "some favicons", logo: "some logo", logo_dark: "some logo_dark", name: "some name"}
  @update_attrs %{favicons: "some updated favicons", logo: "some updated logo", logo_dark: "some updated logo_dark", name: "some updated name"}
  @invalid_attrs %{favicons: nil, logo: nil, logo_dark: nil, name: nil}

  def fixture(:brand) do
    {:ok, brand} = Branding.create_brand(@create_attrs)
    brand
  end

  describe "index" do
    test "lists all brands", %{conn: conn} do
      conn = get(conn, Routes.brand_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Brands"
    end
  end

  describe "new brand" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.brand_path(conn, :new))
      assert html_response(conn, 200) =~ "New Brand"
    end
  end

  describe "create brand" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.brand_path(conn, :create), brand: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.brand_path(conn, :show, id)

      conn = get(conn, Routes.brand_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Brand"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.brand_path(conn, :create), brand: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Brand"
    end
  end

  describe "edit brand" do
    setup [:create_brand]

    test "renders form for editing chosen brand", %{conn: conn, brand: brand} do
      conn = get(conn, Routes.brand_path(conn, :edit, brand))
      assert html_response(conn, 200) =~ "Edit Brand"
    end
  end

  describe "update brand" do
    setup [:create_brand]

    test "redirects when data is valid", %{conn: conn, brand: brand} do
      conn = put(conn, Routes.brand_path(conn, :update, brand), brand: @update_attrs)
      assert redirected_to(conn) == Routes.brand_path(conn, :show, brand)

      conn = get(conn, Routes.brand_path(conn, :show, brand))
      assert html_response(conn, 200) =~ "some updated favicons"
    end

    test "renders errors when data is invalid", %{conn: conn, brand: brand} do
      conn = put(conn, Routes.brand_path(conn, :update, brand), brand: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Brand"
    end
  end

  describe "delete brand" do
    setup [:create_brand]

    test "deletes chosen brand", %{conn: conn, brand: brand} do
      conn = delete(conn, Routes.brand_path(conn, :delete, brand))
      assert redirected_to(conn) == Routes.brand_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.brand_path(conn, :show, brand))
      end
    end
  end

  defp create_brand(_) do
    brand = fixture(:brand)
    %{brand: brand}
  end
end
