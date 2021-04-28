defmodule OliWeb.BrandController do
  use OliWeb, :controller

  require Logger

  alias Oli.Branding
  alias Oli.Branding.Brand
  alias ExAws.S3
  alias ExAws

  def index(conn, _params) do
    brands = Branding.list_brands()
    render_workspace_page(conn, "index.html", brands: brands)
  end

  def new(conn, _params) do
    changeset = Branding.change_brand(%Brand{})
    render_workspace_page(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"brand" => brand_params} = params) do
    case Branding.create_brand(brand_params) do
      {:ok, brand} ->
        # upload files to S3, we assume these will succeed but simply log an error if they do not
        upload_brand_assets(brand, brand_params)

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
        upload_brand_assets(brand, brand_params)

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

  defp upload_brand_assets(brand, brand_params) do
    brand_path = "brands/#{brand.slug}"

    case brand_params["logo"] do
      nil -> nil
      logo ->
        upload("#{brand_path}/#{logo.filename}", logo)
    end

    case brand_params["favicons"] do
      nil -> nil
      favicons ->
        Enum.each(favicons, fn f ->
          upload("#{brand_path}/favicons/#{f.filename}", f)
        end)
    end

    # logo_dark and favicons_dark are optional
    case brand_params["logo_dark"] do
      nil -> nil
      logo_dark ->
        upload("#{brand_path}/#{logo_dark.filename}", logo_dark)
    end

    case brand_params["favicons_dark"] do
      nil -> nil
      favicons_dark ->
        Enum.each(favicons_dark, fn f ->
          upload("#{brand_path}/favicons_dark/#{f.filename}", f)
        end)
    end
  end

  defp upload(path, file) do
    contents = File.read!(file.path)

    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    case upload_file(bucket_name, path, contents) do
      {:ok, %{status_code: 200}} ->
        nil
      _ ->
        Logger.error("Failed to upload file to S3 '#{path}'", file)
    end
  end

  defp upload_file(bucket, path, contents) do
    S3.put_object(bucket, path, contents, [{:acl, :public_read}])
    |> ExAws.request()
  end

end
