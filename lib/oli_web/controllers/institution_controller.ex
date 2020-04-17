defmodule OliWeb.InstitutionController do
  use OliWeb, :controller

  alias Oli.Accounts
  alias Oli.Accounts.Institution

  import Oli.Delivery.{CountryCodes, Timezones}

  def index(conn, _params) do
    institutions = Accounts.list_institutions() |> Enum.filter(fn i -> i.author_id == conn.assigns.current_author.id end)
    render conn, "index.html", institutions: institutions, title: "Institutions"
  end

  def new(conn, _params) do
    changeset = Accounts.change_institution(%Institution{})
    render conn, "new.html", changeset: changeset, country_codes: list_country_codes(), timezones: list_timezones(), title: "Institutions"
  end

  def create(conn, %{"institution" => institution_params}) do
    # Generate a consumer_key and secret and add to institution_params
    consumer_key = UUID.uuid4()
    shared_secret = Oli.Utils.random_string(32)
    author_id = conn.assigns.current_author.id
    institution_params = institution_params
      |> Map.put("consumer_key", consumer_key)
      |> Map.put("shared_secret", shared_secret)
      |> Map.put("author_id", author_id)

    case Accounts.create_institution(institution_params) do
      {:ok, _institution} ->
        conn
        |> put_flash(:info, "Institution created successfully.")
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset, country_codes: list_country_codes(), timezones: list_timezones(), title: "Institutions")
    end
  end

  def show(conn, %{"id" => id}) do
    institution = Accounts.get_institution!(id)
    render conn, "show.html", institution: institution, title: "Institutions"
  end

  def edit(conn, %{"id" => id}) do
    institution = Accounts.get_institution!(id)
    changeset = Accounts.change_institution(institution)
    render(conn, "edit.html", institution: institution, changeset: changeset, country_codes: list_country_codes(), timezones: list_timezones(), title: "Institutions")
  end

  def update(conn, %{"id" => id, "institution" => institution_params}) do
    institution = Accounts.get_institution!(id)

    case Accounts.update_institution(institution, institution_params) do
      {:ok, institution} ->
        conn
        |> put_flash(:info, "Institution updated successfully.")
        |> redirect(to: Routes.institution_path(conn, :show, institution))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", institution: institution, changeset: changeset, country_codes: list_country_codes(), timezones: list_timezones(), title: "Institutions")
    end
  end

  def delete(conn, %{"id" => id}) do
    institution = Accounts.get_institution!(id)
    {:ok, _institution} = Accounts.delete_institution(institution)

    conn
    |> put_flash(:info, "Institution deleted successfully.")
    |> redirect(to: Routes.institution_path(conn, :index))
  end
end
