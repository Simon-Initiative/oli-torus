defmodule OliWeb.InstitutionController do
  use OliWeb, :controller

  alias Oli.Institutions
  alias Oli.Institutions.Institution

  import Oli.Delivery.{CountryCodes, Timezones}

  def index(conn, _params) do
    institutions = Institutions.list_institutions()
    render_institution_page conn, "index.html", institutions: institutions, title: "Institutions"
  end

  def new(conn, _params) do
    changeset = Institutions.change_institution(%Institution{})
    render_institution_page conn, "new.html", changeset: changeset, country_codes: list_country_codes(), timezones: list_timezones(), title: "Institutions"
  end

  def create(conn, %{"institution" => institution_params}) do
    author_id = conn.assigns.current_author.id
    institution_params = institution_params
      |> Map.put("author_id", author_id)

    case Institutions.create_institution(institution_params) do
      {:ok, _institution} ->
        conn
        |> put_flash(:info, "Institution created successfully.")
        |> redirect(to: Routes.static_page_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render_institution_page conn, "new.html", changeset: changeset, country_codes: list_country_codes(), timezones: list_timezones(), title: "Institutions"
    end
  end

  def show(conn, %{"id" => id}) do
    institution = Institutions.get_institution!(id)

    host = Application.get_env(:oli, OliWeb.Endpoint)
      |> Keyword.get(:url)
      |> Keyword.get(:host)

    developer_key_url = "https://#{host}/lti/developer_key.json"

    render_institution_page conn, "show.html", institution: institution, developer_key_url: developer_key_url, title: "Institutions"
  end

  def edit(conn, %{"id" => id}) do
    institution = Institutions.get_institution!(id)
    changeset = Institutions.change_institution(institution)
    render_institution_page conn, "edit.html", institution: institution, changeset: changeset, country_codes: list_country_codes(), timezones: list_timezones(), title: "Institutions"
  end

  def update(conn, %{"id" => id, "institution" => institution_params}) do
    institution = Institutions.get_institution!(id)

    case Institutions.update_institution(institution, institution_params) do
      {:ok, institution} ->
        conn
        |> put_flash(:info, "Institution updated successfully.")
        |> redirect(to: Routes.institution_path(conn, :show, institution))

      {:error, %Ecto.Changeset{} = changeset} ->
        render_institution_page conn, "edit.html", institution: institution, changeset: changeset, country_codes: list_country_codes(), timezones: list_timezones(), title: "Institutions"
    end
  end

  def delete(conn, %{"id" => id}) do
    institution = Institutions.get_institution!(id)
    {:ok, _institution} = Institutions.delete_institution(institution)

    conn
    |> put_flash(:info, "Institution deleted successfully.")
    |> redirect(to: Routes.institution_path(conn, :index))
  end

  defp render_institution_page(conn, template, assigns) do
    render conn, template, Keyword.put_new(assigns, :active, :institutions)
  end

end
