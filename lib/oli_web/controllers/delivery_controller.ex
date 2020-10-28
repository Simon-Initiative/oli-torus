defmodule OliWeb.DeliveryController do
  use OliWeb, :controller
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing
  alias Oli.Institutions
  alias Oli.Lti_1p3.ContextRoles

  @context_administrator ContextRoles.get_role(:context_administrator)
  @context_instructor ContextRoles.get_role(:context_instructor)

  def index(conn, _params) do
    user = conn.assigns.current_user
    lti_params = conn.assigns.lti_params

    context_id = lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["id"]
    section = Sections.get_section_by(context_id: context_id)

    lti_roles = lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]
    context_roles = ContextRoles.get_roles_by_uris(lti_roles)
    role = ContextRoles.get_highest_role(context_roles)

    case {role, user.author, section} do
      # author account has not been linked
      {role, nil, nil} when role == @context_administrator or role == @context_instructor ->
        render_getting_started(conn, context_id)

      # section has not been configured
      {role, author, nil} when role == @context_administrator or role == @context_instructor ->
        render_configure_section(conn, context_id, author)

      {_role, _author, nil} ->
        render_course_not_configured(conn, context_id)

      # section has been configured
      {_role, _author, section} ->
        redirect_to_page_delivery(conn, section)
    end

  end

  defp render_course_not_configured(conn, context_id) do
    render(conn, "course_not_configured.html", context_id: context_id)
  end


  defp render_getting_started(conn, context_id) do
    render(conn, "getting_started.html", context_id: context_id)
  end

  defp render_configure_section(conn, context_id, author) do
    publications = Publishing.available_publications(author)
    my_publications = publications |> Enum.filter(fn p -> !p.open_and_free && p.published end)
    open_and_free_publications = publications |> Enum.filter(fn p -> p.open_and_free && p.published end)
    render(conn, "configure_section.html", context_id: context_id, author: author, my_publications: my_publications, open_and_free_publications: open_and_free_publications)
  end

  defp redirect_to_page_delivery(conn, section) do
    redirect(conn, to: Routes.page_delivery_path(conn, :index, section.context_id))
  end

  def list_open_and_free(conn, _params) do
    open_and_free_publications = Publishing.available_publications()
    render(conn, "configure_section.html", open_and_free_publications: open_and_free_publications)
  end

  def link_account(conn, _params) do
    # sign out current author account
    conn = conn
      |> use_pow_config(:author)
      |> Pow.Plug.delete()

    assigns = conn.assigns
      |> Map.put(:title, "Link Existing Account")
      |> Map.put(:changeset, Oli.Accounts.Author.changeset(%Oli.Accounts.Author{}))
      |> Map.put(:action, Routes.pow_session_path(conn, :create))
      |> Map.put(:link_account, true)
      |> Map.put(:create_account_path, Routes.delivery_path(conn, :create_and_link_account))
      |> Map.put(:cancel_path, Routes.delivery_path(conn, :index))

    conn
    |> put_view(OliWeb.Pow.SessionView)
    |> render("new.html", assigns)
  end

  def process_link_account(conn, %{"provider" => provider}) do

    IO.inspect provider, label: "process_link_account"

    # PowAssent.Plug.authorize_url(conn, provider, conn.assigns.callback_url)
    # PowAssent.Plug.authorize_url(conn, provider, "/auth/google/new?type=link_account")
    PowAssent.Plug.authorize_url(conn, provider, Routes.delivery_path(conn, :link_account_callback, provider))
    |> case do
      {:ok, url, conn} ->
      conn
      |> redirect(to: url)
    end
  end

  def link_account_callback(conn, %{"provider" => provider} = params) do

    IO.inspect "link_account_callback"

    PowAssent.Plug.callback_upsert(conn, provider, params, conn.assigns.callback_url)
  end

  def create_and_link_account(conn, _params) do
    # sign out current author account
    conn = conn
      |> use_pow_config(:author)
      |> Pow.Plug.delete()

    assigns = conn.assigns
      |> Map.put(:title, "Create and Link Account")
      |> Map.put(:changeset, Oli.Accounts.Author.changeset(%Oli.Accounts.Author{}))
      |> Map.put(:action, Routes.pow_registration_path(conn, :create))
      |> Map.put(:link_account, true)
      |> Map.put(:sign_in_path, Routes.delivery_path(conn, :link_account))
      |> Map.put(:cancel_path, Routes.delivery_path(conn, :index))

    conn
    |> put_view(OliWeb.Pow.RegistrationView)
    |> render("new.html", assigns)
  end

  def create_section(conn, %{"publication_id" => publication_id}) do
    lti_params = conn.assigns.lti_params
    user = conn.assigns.current_user
    institution = Institutions.get_institution!(user.institution_id)
    publication = Publishing.get_publication!(publication_id)

    {:ok, %Section{id: section_id}} = Sections.create_section(%{
      time_zone: institution.timezone,
      title: lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["title"],
      context_id: lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["id"],
      institution_id: user.institution_id,
      project_id: publication.project_id,
      publication_id: publication_id,
    })

    # Enroll this user with their proper roles (instructor)
    lti_roles = lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]
    context_roles = ContextRoles.get_roles_by_uris(lti_roles)
    Sections.enroll(user.id, section_id, context_roles)

    conn
    |> redirect(to: Routes.delivery_path(conn, :index))
  end

  def signout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: Routes.delivery_path(conn, :index))
  end

end
