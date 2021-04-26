defmodule OliWeb.BrandController do
  use OliWeb, :controller

  alias Oli.Branding
  alias Oli.Branding.Brand

  def index(conn, _params) do
    brands = Branding.list_brands()
    render_workspace_page(conn, "index.html", brands: brands)
  end

  def new(conn, _params) do
    changeset = Branding.change_brand(%Brand{})
    render_workspace_page(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"brand" => brand_params}) do
    case Branding.create_brand(brand_params) do
      {:ok, brand} ->
        conn
        |> put_flash(:info, "Brand created successfully.")
        |> redirect(to: Routes.brand_path(conn, :show, brand))

      {:error, %Ecto.Changeset{} = changeset} ->
        render_workspace_page(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    brand = Branding.get_brand!(id)
    render_workspace_page(conn, "show.html", brand: brand)
  end

  def edit(conn, %{"id" => id}) do
    brand = Branding.get_brand!(id)
    changeset = Branding.change_brand(brand)
    render_workspace_page(conn, "edit.html", brand: brand, changeset: changeset)
  end

  def update(conn, %{"id" => id, "brand" => brand_params}) do
    brand = Branding.get_brand!(id)

    case Branding.update_brand(brand, brand_params) do
      {:ok, brand} ->
        conn
        |> put_flash(:info, "Brand updated successfully.")
        |> redirect(to: Routes.brand_path(conn, :show, brand))

      {:error, %Ecto.Changeset{} = changeset} ->
        render_workspace_page(conn, "edit.html", brand: brand, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    brand = Branding.get_brand!(id)
    {:ok, _brand} = Branding.delete_brand(brand)

    conn
    |> put_flash(:info, "Brand deleted successfully.")
    |> redirect(to: Routes.brand_path(conn, :index))
  end

  defp render_workspace_page(conn, template, assigns) do
    render(conn, template, Keyword.merge(assigns, active: :brands, title: "Brands"))
  end
end
