defmodule OliWeb.InstitutionController do
  use OliWeb, :controller

  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Lti_1p3.Registration
  alias Oli.Lti_1p3.Deployment

  import Oli.Delivery.{CountryCodes, Timezones}

  def index(conn, _params) do
    institutions = Institutions.list_institutions() |> Enum.filter(fn i -> i.author_id == conn.assigns.current_author.id end)
    render conn, "index.html", institutions: institutions, title: "Institutions"
  end

  def new(conn, _params) do
    changeset = Institutions.change_institution(%Institution{})
    render conn, "new.html", changeset: changeset, country_codes: list_country_codes(), timezones: list_timezones(), title: "Institutions"
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
        render(conn, "new.html", changeset: changeset, country_codes: list_country_codes(), timezones: list_timezones(), title: "Institutions")
    end
  end

  def show(conn, %{"id" => id}) do
    institution = Institutions.get_institution!(id)
    render conn, "show.html", institution: institution, title: "Institutions"
  end

  def edit(conn, %{"id" => id}) do
    institution = Institutions.get_institution!(id)
    changeset = Institutions.change_institution(institution)
    render(conn, "edit.html", institution: institution, changeset: changeset, country_codes: list_country_codes(), timezones: list_timezones(), title: "Institutions")
  end

  def update(conn, %{"id" => id, "institution" => institution_params}) do
    institution = Institutions.get_institution!(id)

    case Institutions.update_institution(institution, institution_params) do
      {:ok, institution} ->
        conn
        |> put_flash(:info, "Institution updated successfully.")
        |> redirect(to: Routes.institution_path(conn, :show, institution))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", institution: institution, changeset: changeset, country_codes: list_country_codes(), timezones: list_timezones(), title: "Institutions")
    end
  end

  def delete(conn, %{"id" => id}) do
    institution = Institutions.get_institution!(id)
    {:ok, _institution} = Institutions.delete_institution(institution)

    conn
    |> put_flash(:info, "Institution deleted successfully.")
    |> redirect(to: Routes.institution_path(conn, :index))
  end

  def new_registration(conn, %{"institution_id" => institution_id}) do
    changeset = Institutions.change_registration(%Registration{institution_id: institution_id})
    render(conn, "registration/new.html", changeset: changeset)
  end

  def create_registration(conn, %{"institution_id" => _institution_id, "registration" => registration_params}) do
    case Institutions.create_registration(registration_params) do
      {:ok, registration} ->
        conn
        |> put_flash(:info, "Registration created successfully.")
        |> redirect(to: Routes.registration_path(conn, :show, registration))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "registration/new.html", changeset: changeset)
    end
  end

  def edit_registration(conn, %{"institution_id" => _institution_id, "id" => id}) do
    registration = Institutions.get_registration!(id)
    changeset = Institutions.change_registration(registration)
    render(conn, "registration/edit.html", registration: registration, changeset: changeset)
  end

  def update_registration(conn, %{"institution_id" => _institution_id, "id" => id, "registration" => registration_params}) do
    registration = Institutions.get_registration!(id)

    case Institutions.update_registration(registration, registration_params) do
      {:ok, registration} ->
        conn
        |> put_flash(:info, "Registration updated successfully.")
        |> redirect(to: Routes.registration_path(conn, :show, registration))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "registration/edit.html", registration: registration, changeset: changeset)
    end
  end

  def delete_registration(conn, %{"institution_id" => _institution_id, "id" => id}) do
    registration = Institutions.get_registration!(id)
    {:ok, _registration} = Institutions.delete_registration(registration)

    conn
    |> put_flash(:info, "Registration deleted successfully.")
    |> redirect(to: Routes.registration_path(conn, :index))
  end

  def new_deployment(conn, %{"institution_id" => _institution_id, "registration_id" => registration_id}) do
    changeset = Institutions.change_deployment(%Deployment{registration_id: registration_id})
    render(conn, "deployment/new.html", changeset: changeset)
  end

  def create_deployment(conn, %{"institution_id" => _institution_id, "registration_id" => _registration_id, "deployment" => deployment_params}) do
    case Institutions.create_deployment(deployment_params) do
      {:ok, deployment} ->
        conn
        |> put_flash(:info, "Deployment created successfully.")
        |> redirect(to: Routes.deployment_path(conn, :show, deployment))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "deployment/new.html", changeset: changeset)
    end
  end

  def edit_deployment(conn, %{"institution_id" => _institution_id, "registration_id" => _registration_id, "id" => id}) do
    deployment = Institutions.get_deployment!(id)
    changeset = Institutions.change_deployment(deployment)
    render(conn, "deployment/edit.html", deployment: deployment, changeset: changeset)
  end

  def update_deployment(conn, %{"institution_id" => _institution_id, "registration_id" => _registration_id, "id" => id, "deployment" => deployment_params}) do
    deployment = Institutions.get_deployment!(id)

    case Institutions.update_deployment(deployment, deployment_params) do
      {:ok, deployment} ->
        conn
        |> put_flash(:info, "Deployment updated successfully.")
        |> redirect(to: Routes.deployment_path(conn, :show, deployment))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "deployment/edit.html", deployment: deployment, changeset: changeset)
    end
  end

  def delete_deployment(conn, %{"institution_id" => _institution_id, "registration_id" => _registration_id, "id" => id}) do
    deployment = Institutions.get_deployment!(id)
    {:ok, _deployment} = Institutions.delete_deployment(deployment)

    conn
    |> put_flash(:info, "Deployment deleted successfully.")
    |> redirect(to: Routes.deployment_path(conn, :index))
  end
end
