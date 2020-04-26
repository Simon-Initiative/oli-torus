defmodule OliWeb.DeliveryController do
  use OliWeb, :controller
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias Oli.Accounts

  alias Oli.Delivery.Lti

  def index(conn, _params) do
    user = conn.assigns.current_user
    lti_params = get_session(conn, :lti_params)
    section = Sections.get_section_by(context_id: lti_params["context_id"])
    pages = Publishing.get_published_revisions(section.publication)

    case {Lti.parse_lti_role(user.roles), user.author, section} do
      {:student, _author, nil} ->
        render(conn, "course_not_configured.html")
      {:student, _author, section} ->
        render(conn, "student_view.html", section: section, pages: pages)
      {role, nil, nil} when role == :administrator or role == :instructor ->
        render(conn, "getting_started.html")
      {role, author, nil} when role == :administrator or role == :instructor ->
        publications = Publishing.available_publications(author)
        my_publications = publications |> Enum.filter(fn p -> !p.open_and_free && p.published end)
        open_and_free_publications = publications |> Enum.filter(fn p -> p.open_and_free && p.published end)
        render(conn, "configure_section.html", author: author, my_publications: my_publications, open_and_free_publications: open_and_free_publications)
      {role, _author, section} when role == :administrator or role == :instructor ->
        render(conn, "instructor_view.html", section: section, pages: pages)
    end
  end

  def resource(conn, _params) do
    page = %{}
    render(conn, "page.html", page: page)
  end

  def list_open_and_free(conn, _params) do
    open_and_free_publications = Publishing.available_publications()
    render(conn, "configure_section.html", open_and_free_publications: open_and_free_publications)
  end

  def link_account(conn, _params) do
    actions = %{
      google: Routes.auth_path(conn, :request, "google", type: "link-account"),
      facebook: Routes.auth_path(conn, :request, "facebook", type: "link-account"),
      identity: Routes.auth_path(conn, :identity_callback, type: "link-account"),
    }

    assigns = conn.assigns
    |> Map.put(:title, "Link Existing Account")
    |> Map.put(:actions, actions)
    |> Map.put(:show_remember_password, false)

    conn
    |> put_view(OliWeb.AuthView)
    |> render("signin.html", assigns)
  end

  def create_and_link_account(conn, _params) do
    actions = %{
      google: Routes.auth_path(conn, :request, "google", type: "link-account"),
      facebook: Routes.auth_path(conn, :request, "facebook", type: "link-account"),
      identity: Routes.auth_path(conn, :register_email_form, type: "link-account"),
    }

    assigns = conn.assigns
    |> Map.put(:title, "Create and Link Account")
    |> Map.put(:actions, actions)
    |> Map.put(:show_remember_password, false)

    conn
    |> put_view(OliWeb.AuthView)
    |> render("register.html", assigns)
  end

  def create_section(conn, %{"publication_id" => publication_id}) do
    lti_params = get_session(conn, :lti_params)
    user = conn.assigns.current_user
    institution = Accounts.get_institution!(user.institution_id)
    publication = Publishing.get_publication!(publication_id)

    Sections.create_section(%{
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
