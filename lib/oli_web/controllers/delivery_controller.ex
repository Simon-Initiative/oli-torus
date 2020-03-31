defmodule OliWeb.DeliveryController do
  use OliWeb, :controller

  alias Oli.Lti

  def index(conn, _params) do
    user = conn.assigns.current_user
    lti_params = get_session(conn, :lti_params)
    section = Oli.Sections.get_section_by(context_id: lti_params["context_id"])

    case {Lti.parse_lti_role(user.roles), user.author, section} do
      {:student, _author, nil} ->
        render(conn, "course_not_configured.html")
      {:student, _author, section} ->
        render(conn, "student_view.html", section: section)
      {role, nil, nil} when role == :administrator or role == :instructor ->
        render(conn, "getting_started.html")
      {role, author, nil} when role == :administrator or role == :instructor ->
        publications = Oli.Publishing.available_publications(author)
        render(conn, "configure_section.html", publications: publications)
      {role, _author, section} when role == :administrator or role == :instructor ->
        render(conn, "instructor_view.html", section: section)
    end
  end

  def link_account(conn, _params) do
    actions = %{
      google: Routes.auth_path(conn, :request, "google", type: "link-account"),
      facebook: Routes.auth_path(conn, :request, "facebook", type: "link-account"),
      identity: Routes.auth_path(conn, :identity_callback, type: "link-account"),
      cancel: Routes.delivery_path(conn, :index),
    }

    assigns = conn.assigns
    |> Map.put(:title, "Link Existing Account")
    |> Map.put(:actions, actions)
    |> Map.put(:show_remember_password, false)
    |> Map.put(:show_cancel, true)

    conn
    |> put_view(OliWeb.AuthView)
    |> render("signin.html", assigns)
  end

  def create_section(conn, %{"publication_id" => publication_id}) do
    lti_params = get_session(conn, :lti_params)
    user = conn.assigns.current_user
    institution = Oli.Accounts.get_institution!(user.institution_id)
    publication = Oli.Publishing.get_publication!(publication_id)

    Oli.Sections.create_section(%{
      time_zone: institution.timezone,
      title: lti_params["context_title"],
      context_id: lti_params["context_id"],
      institution_id: user.institution_id,
      project_id: publication.project_id,
      publication_id: publication_id,
    })

    conn
    |> redirect(to: Routes.delivery_path(conn, :index))
  end

  def signout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: Routes.delivery_path(conn, :index))
  end

end
