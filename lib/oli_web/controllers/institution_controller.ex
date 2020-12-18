defmodule OliWeb.InstitutionController do
  use OliWeb, :controller

  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Predefined

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

  def approve_registration() do

    # case Ecto.Changeset.apply_action(PendingRegistration.changeset(%PendingRegistration{}, ir_attrs), :update) do
    #   {:ok, _data} ->
    #     with {:ok, institution} <- Institutions.create_institution(ir_attrs),
    #          active_jwk = Oli.Lti_1p3.get_active_jwk(),
    #          registration_attrs = Map.merge(ir_attrs, %{"institution_id" => institution.id, "tool_jwk_id" => active_jwk.id}),
    #          {:ok, _registration} <- Oli.Institutions.create_registration(registration_attrs)
    #     do
    #       conn
    #       |> render("registration_pending.html")

    #     else
    #       error ->
    #         Logger.error("Failed to submit registration request", error)
    #         conn
    #         |> render("lti_error.html", reason: "Failed to submit registration request")
    #     end
    # end
  end

  defp render_institution_page(conn, template, assigns) do
    render conn, template, Keyword.merge(assigns, [active: :institutions, title: "Institutions"])
  end

end
