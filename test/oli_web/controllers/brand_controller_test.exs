defmodule OliWeb.BrandControllerTest do
  use OliWeb.ConnCase

  import Mox

  alias Oli.Branding
  alias Oli.Branding.Brand

  @create_attrs %{
    "favicons" => [
      %Plug.Upload{
        path: Path.absname("priv/data/oli_favicons/favicon.ico"),
        filename: "some_favicon.ico"
      }
    ],
    "logo" => %Plug.Upload{
      path: Path.absname("priv/data/oli_logo.png"),
      filename: "some_logo.png"
    },
    "logo_dark" => %Plug.Upload{
      path: Path.absname("priv/data/oli_logo.png"),
      filename: "some_logo_dark.png"
    },
    "name" => "some name"
  }
  @update_attrs %{
    "favicons" => [
      %Plug.Upload{
        path: Path.absname("priv/data/oli_favicons/favicon.ico"),
        filename: "some_updated_favicon.ico"
      }
    ],
    "logo" => %Plug.Upload{
      path: Path.absname("priv/data/oli_logo.png"),
      filename: "some_update_logo.png"
    },
    "logo_dark" => %Plug.Upload{
      path: Path.absname("priv/data/oli_logo.png"),
      filename: "some_update_logo_dark.png"
    },
    "name" => "some updated name"
  }
  @invalid_attrs %{
    "favicons" => nil,
    "logo" => nil,
    "logo_dark" => nil,
    "name" => nil
  }

  def fixture(:brand) do
    {:ok, brand} = Branding.create_brand(Brand.cast_file_params(@create_attrs))
    brand
  end

  describe "index" do
    setup [:create_and_signin_admin]

    test "lists all brands", %{conn: conn} do
      conn = get(conn, Routes.brand_path(conn, :index))
      assert html_response(conn, 200) =~ "Brands"
      assert html_response(conn, 200) =~ "New Brand"
      assert html_response(conn, 200) =~ "There are no brands"
    end
  end

  describe "index with brand" do
    setup [:create_and_signin_admin, :create_brand]

    test "lists all brands", %{conn: conn} do
      conn = get(conn, Routes.brand_path(conn, :index))
      assert html_response(conn, 200) =~ "Brands"
      assert html_response(conn, 200) =~ "New Brand"

      assert html_response(conn, 200) =~ "some name"
    end
  end

  describe "new brand" do
    setup [:create_and_signin_admin]

    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.brand_path(conn, :new))
      assert html_response(conn, 200) =~ "Create Brand"
    end
  end

  describe "create brand" do
    setup [:create_and_signin_admin]

    test "redirects to show when data is valid", %{conn: conn, admin: admin} do
      Oli.Test.MockAws
      |> expect(:request, 2, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200}}
      end)

      conn = post(conn, Routes.brand_path(conn, :create), brand: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.brand_path(conn, :show, id)

      conn = recycle_author_session(conn, admin)

      conn = get(conn, Routes.brand_path(conn, :show, id))
      assert html_response(conn, 200) =~ @create_attrs["name"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.brand_path(conn, :create), brand: @invalid_attrs)
      assert html_response(conn, 200) =~ "Create Brand"
    end
  end

  describe "edit brand" do
    setup [:create_and_signin_admin, :create_brand]

    test "renders form for editing chosen brand", %{conn: conn, brand: brand} do
      conn = get(conn, Routes.brand_path(conn, :edit, brand))
      assert html_response(conn, 200) =~ "Edit Brand"
    end
  end

  describe "update brand" do
    setup [:create_and_signin_admin, :create_brand]

    test "redirects when data is valid", %{conn: conn, brand: brand, admin: admin} do
      Oli.Test.MockAws
      |> expect(:request, 2, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200}}
      end)

      conn = put(conn, Routes.brand_path(conn, :update, brand), brand: @update_attrs)
      assert redirected_to(conn) == Routes.brand_path(conn, :show, brand)

      conn = recycle_author_session(conn, admin)

      conn = get(conn, Routes.brand_path(conn, :show, brand))
      assert html_response(conn, 200) =~ @update_attrs["name"]
    end

    test "renders errors when data is invalid", %{conn: conn, brand: brand} do
      conn = put(conn, Routes.brand_path(conn, :update, brand), brand: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Brand"
    end
  end

  describe "delete brand" do
    setup [:create_and_signin_admin, :create_brand]

    test "deletes chosen brand", %{conn: conn, brand: brand, admin: admin} do
      conn = delete(conn, Routes.brand_path(conn, :delete, brand))
      assert redirected_to(conn) == Routes.brand_path(conn, :index)

      conn = recycle_author_session(conn, admin)

      assert_error_sent 404, fn ->
        get(conn, Routes.brand_path(conn, :show, brand))
      end
    end
  end

  defp create_and_signin_admin(%{conn: conn}) do
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().system_admin})

    conn =
      conn
      |> assign_current_author(admin)

    %{conn: conn, admin: admin}
  end

  defp create_brand(_) do
    brand = fixture(:brand)
    %{brand: brand}
  end
end
