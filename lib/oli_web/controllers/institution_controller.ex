defmodule OliWeb.InstitutionController do
  use OliWeb, :controller

  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Predefined

  require Logger

  def index(conn, _params) do
    institutions = Institutions.list_institutions()
    pending_registrations = Institutions.list_pending_registrations()

    render_institution_page conn, "index.html", institutions: institutions, pending_registrations: pending_registrations,
      country_codes: Predefined.country_codes(), timezones: Predefined.timezones(), lti_config_defaults: Predefined.lti_config_defaults(), world_universities_and_domains: Predefined.world_universities_and_domains()
  end

  def new(conn, _params) do
    changeset = Institutions.change_institution(%Institution{})
    render_institution_page conn, "new.html", changeset: changeset, country_codes: Predefined.country_codes(), timezones: Predefined.timezones()
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
        render_institution_page conn, "new.html", changeset: changeset, country_codes: Predefined.country_codes(), timezones: Predefined.timezones()
    end
  end

  def show(conn, %{"id" => id}) do
    institution = Institutions.get_institution!(id)

    host = Application.get_env(:oli, OliWeb.Endpoint)
      |> Keyword.get(:url)
      |> Keyword.get(:host)

    developer_key_url = "https://#{host}/lti/developer_key.json"

    render_institution_page conn, "show.html", institution: institution, developer_key_url: developer_key_url
  end

  def edit(conn, %{"id" => id}) do
    institution = Institutions.get_institution!(id)
    changeset = Institutions.change_institution(institution)
    render_institution_page conn, "edit.html", institution: institution, changeset: changeset, country_codes: Predefined.country_codes(), timezones: Predefined.timezones()
  end

  def update(conn, %{"id" => id, "institution" => institution_params}) do
    institution = Institutions.get_institution!(id)

    case Institutions.update_institution(institution, institution_params) do
      {:ok, institution} ->
        conn
        |> put_flash(:info, "Institution updated successfully.")
        |> redirect(to: Routes.institution_path(conn, :show, institution))

      {:error, %Ecto.Changeset{} = changeset} ->
        render_institution_page conn, "edit.html", institution: institution, changeset: changeset, country_codes: Predefined.country_codes(), timezones: Predefined.timezones()
    end
  end

  def delete(conn, %{"id" => id}) do
    institution = Institutions.get_institution!(id)
    {:ok, _institution} = Institutions.delete_institution(institution)

    conn
    |> put_flash(:info, "Institution deleted successfully.")
    |> redirect(to: Routes.institution_path(conn, :index))
  end

  def approve_registration(conn, %{"pending_registration" => pending_registration_attrs} = params) do
    issuer = pending_registration_attrs["issuer"]
    client_id = pending_registration_attrs["client_id"]

    # no need to persist the pending registration changes since we would just turn around
    # and delete it, but we do want to validate the changes using ecto apply_action
    # case Ecto.Changeset.apply_action(PendingRegistration.changeset(%PendingRegistration{}, pending_registration_attrs), :update) do
    case Institutions.get_pending_registration_by_issuer_client_id(issuer, client_id) do
      nil ->
        conn
        |> put_flash(:error, "Pending registration with issuer '#{issuer}' and client_id '#{client_id}' does not exist")
        |> redirect(to: Routes.institution_path(conn, :index))

      pending_registration ->
        with {:ok, pending_registration} <- Institutions.update_pending_registration(pending_registration, pending_registration_attrs),
             {:ok, {institution, _registration}} <- Institutions.approve_pending_registration(pending_registration)
        do
          conn
          |> put_flash(:info, "Registration approved")
          |> redirect(to: Routes.institution_path(conn, :show, institution))
        else
          error ->
            Logger.error("Failed to approve registration request", error)

            conn
            |> put_flash(:error, "Failed to approve registration. Please double check your entries and try again.")
            |> redirect(to: Routes.institution_path(conn, :index))
        end
    end

  end

  defp render_institution_page(conn, template, assigns) do
    render conn, template, Keyword.merge(assigns, [active: :institutions, title: "Institutions"])
  end

end
