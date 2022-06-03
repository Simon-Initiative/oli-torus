defmodule OliWeb.BrandController do
  use OliWeb, :controller

  alias Oli.Branding
  alias Oli.Branding.Brand
  alias Oli.Repo
  alias Oli.Institutions
  alias OliWeb.Common.Breadcrumb
  alias Oli.Utils.S3Storage

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def new_breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "New Brand"
        })
      ]
  end

  def edit_breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Edit Brand"
        })
      ]
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Manage Brands",
          link: Routes.brand_path(OliWeb.Endpoint, :index)
        })
      ]
  end

  defp available_institutions() do
    Institutions.list_institutions()
    |> Enum.map(fn institution -> {institution.name, institution.id} end)
  end

  def index(conn, _params) do
    brands = Branding.list_brands_with_stats()
    render_workspace_page(conn, "index.html", brands: brands, breadcrumbs: set_breadcrumbs())
  end

  def new(conn, _params) do
    changeset = Branding.change_brand(%Brand{})

    render_workspace_page(conn, "new.html",
      changeset: changeset,
      breadcrumbs: set_breadcrumbs() |> new_breadcrumb(),
      available_institutions: available_institutions()
    )
  end

  def create(conn, %{"brand" => brand_params}) do
    case Branding.create_brand(Brand.cast_file_params(brand_params)) do
      {:ok, brand} ->
        # upload files to S3, we assume these will succeed but simply log an error if they do not
        upload_brand_assets(brand, brand_params)

        conn
        |> put_flash(:info, "Brand created successfully.")
        |> redirect(to: Routes.brand_path(conn, :show, brand))

      {:error, %Ecto.Changeset{} = changeset} ->
        render_workspace_page(conn, "new.html",
          changeset: changeset,
          breadcrumbs: set_breadcrumbs() |> new_breadcrumb(),
          available_institutions: available_institutions()
        )
    end
  end

  def show(conn, %{"id" => id}) do
    brand = Branding.get_brand!(id) |> Repo.preload([:institution])
    render_workspace_page(conn, "show.html", brand: brand)
  end

  def edit(conn, %{"id" => id}) do
    brand = Branding.get_brand!(id)
    changeset = Branding.change_brand(brand)

    render_workspace_page(conn, "edit.html",
      brand: brand,
      breadcrumbs: set_breadcrumbs() |> edit_breadcrumb(),
      changeset: changeset,
      available_institutions: available_institutions()
    )
  end

  def update(conn, %{"id" => id, "brand" => brand_params}) do
    brand = Branding.get_brand!(id)

    case Branding.update_brand(brand, Brand.cast_file_params(brand_params)) do
      {:ok, brand} ->
        upload_brand_assets(brand, brand_params)

        conn
        |> put_flash(:info, "Brand updated successfully.")
        |> redirect(to: Routes.brand_path(conn, :show, brand))

      {:error, %Ecto.Changeset{} = changeset} ->
        render_workspace_page(conn, "edit.html",
          brand: brand,
          changeset: changeset,
          breadcrumbs: set_breadcrumbs() |> edit_breadcrumb(),
          available_institutions: available_institutions()
        )
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

  defp upload_brand_assets(brand, brand_params) do
    brand_path = "brands/#{brand.slug}"
    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    case brand_params["logo"] do
      nil ->
        nil

      logo ->
        S3Storage.upload_file(bucket_name, "#{brand_path}/#{logo.filename}", logo)
    end

    valid_favicon_names = [
      "favicon",
      "favicon-32x32",
      "favicon-16x16",
      "apple-touch-icon",
      "android-chrome-512x512",
      "android-chrome-192x192"
    ]

    case brand_params["favicons"] do
      nil ->
        nil

      favicons ->
        favicons
        |> Enum.filter(fn f ->
          Regex.replace(~r/\.[^.]+$/, f.filename, "") in valid_favicon_names
        end)
        |> Enum.each(fn f ->
          S3Storage.upload_file(bucket_name, "#{brand_path}/favicons/#{f.filename}", f)
        end)
    end

    # logo_dark is optional
    case brand_params["logo_dark"] do
      nil ->
        nil

      logo_dark ->
        S3Storage.upload_file(bucket_name, "#{brand_path}/#{logo_dark.filename}", logo_dark)
    end
  end
end
