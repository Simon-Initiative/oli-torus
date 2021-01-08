defmodule OliWeb.InstitutionController do
  use OliWeb, :controller

  import Phoenix.HTML.Tag

  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Predefined
  alias Oli.Slack

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
        |> put_flash(:info, "Institution created")
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
        |> put_flash(:info, "Institution updated")
        |> redirect(to: Routes.institution_path(conn, :show, institution))

      {:error, %Ecto.Changeset{} = changeset} ->
        render_institution_page conn, "edit.html", institution: institution, changeset: changeset, country_codes: Predefined.country_codes(), timezones: Predefined.timezones()
    end
  end

  def delete(conn, %{"id" => id}) do
    institution = Institutions.get_institution!(id)
    {:ok, _institution} = Institutions.delete_institution(institution)

    conn
    |> put_flash(:info, "Institution deleted")
    |> redirect(to: Routes.institution_path(conn, :index))
  end

  def approve_registration(conn, %{"pending_registration" => pending_registration_attrs} = _params) do
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
             {:ok, {institution, registration}} <- Institutions.approve_pending_registration(pending_registration)
        do
          registration_approved_email = Oli.Email.create_email(
            institution.institution_email,
            "Registration Approved",
            "registration_approved.html",
            %{institution: institution, registration: registration})

          Oli.Mailer.deliver_now(registration_approved_email)

          # send a Slack notification regarding the new registration approval
          approving_admin = conn.assigns[:current_author]
          Slack.send(%{
            "username" => approving_admin.name,
            "icon_emoji" => ":robot_face:",
            "blocks" => [
              %{
                "type" => "section",
                "text" => %{
                  "type" => "mrkdwn",
                  "text" => "Registration request for *#{pending_registration.name}* has been approved."
                }
              }
            ]
          })

          conn
          |> put_flash(:info, ["Registration for ", content_tag(:b, pending_registration.name), " approved"])
          |> redirect(to: Routes.institution_path(conn, :index) <> "#pending-registrations")

        else
          error ->
            Logger.error("Failed to approve registration request", error)

            conn
            |> put_flash(:error, "Failed to approve registration. Please double check your entries and try again.")
            |> redirect(to: Routes.institution_path(conn, :index))
        end
    end

  end

  def remove_registration(conn, %{"id" => id}) do
    pending_registration = Institutions.get_pending_registration!(id)
    {:ok, _pending_registration} = Institutions.delete_pending_registration(pending_registration)

    # send a Slack notification regarding the new registration approval
    approving_admin = conn.assigns[:current_author]
    Slack.send(%{
      "username" => approving_admin.name,
      "icon_emoji" => ":robot_face:",
      "blocks" => [
        %{
          "type" => "section",
          "text" => %{
            "type" => "mrkdwn",
            "text" => "Registration for *#{pending_registration.name}* has been declined."
          }
        }
      ]
    })

    conn
    |> put_flash(:info, ["Registration for ", content_tag(:b, pending_registration.name), " declined"])
    |> redirect(to: Routes.institution_path(conn, :index))
  end

  defp render_institution_page(conn, template, assigns) do
    render conn, template, Keyword.merge(assigns, [active: :institutions, title: "Institutions"])
  end

end
