defmodule OliWeb.DeliveryController do
  use OliWeb, :controller
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing

  alias Oli.Institutions
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Accounts
  alias Oli.Accounts.Author

  @context_administrator ContextRoles.get_role(:context_administrator)
  @context_instructor ContextRoles.get_role(:context_instructor)

  plug Oli.Plugs.RegistrationCaptcha when action in [:process_create_and_link_account_user]

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

    render(conn, "configure_section.html", context_id: context_id, author: author, my_publications: my_publications)
  end

  defp redirect_to_page_delivery(conn, section) do
    redirect(conn, to: Routes.page_delivery_path(conn, :index, section.context_id))
  end

  def link_account(conn, _params) do
    # sign out current author account
    conn = conn
      |> use_pow_config(:author)
      |> Pow.Plug.delete()

    conn
    |> render_link_account_form()
  end

  def render_link_account_form(conn, opts \\ []) do
    title = Keyword.get(opts, :title, "Link Existing Account")
    changeset = Keyword.get(opts, :changeset, Author.noauth_changeset(%Author{}))
    action = Keyword.get(opts, :action, Routes.delivery_path(conn, :process_link_account_user))
    create_account_path = Keyword.get(opts, :create_account_path, Routes.delivery_path(conn, :create_and_link_account))
    cancel_path = Keyword.get(opts, :cancel_path, Routes.delivery_path(conn, :index))

    conn
    |> assign(:title, title)
    |> assign(:changeset, changeset)
    |> assign(:action, action)
    |> assign(:create_account_path, create_account_path)
    |> assign(:cancel_path, cancel_path)
    |> assign(:link_account, true)
    |> put_view(OliWeb.Pow.SessionView)
    |> render("new.html")
  end

  def process_link_account_provider(conn, %{"provider" => provider}) do
    conn = conn
      |> merge_assigns(callback_url: Routes.delivery_url(conn, :link_account_callback, provider))

    PowAssent.Plug.authorize_url(conn, provider, conn.assigns.callback_url)
    |> case do
      {:ok, url, conn} ->
      conn
      |> redirect(external: url)
    end
  end

  def process_link_account_user(conn, %{"user" => author_params}) do
    conn
    |> use_pow_config(:author)
    |> Pow.Plug.authenticate_user(author_params)
    |> case do
      {:ok, conn} ->
        conn
        |> put_flash(:info, Pow.Phoenix.Controller.messages(conn, Pow.Phoenix.Messages).signed_in(conn))
        |> redirect(to: Pow.Phoenix.Controller.routes(conn, Pow.Phoenix.Routes).after_sign_in_path(conn))

      {:error, conn} ->
        conn
        |> put_flash(:error, Pow.Phoenix.Controller.messages(conn, Pow.Phoenix.Messages).invalid_credentials(conn))
        |> render_link_account_form(changeset: PowAssent.Plug.change_user(conn, %{}, author_params))
    end
  end

  def link_account_callback(conn, %{"provider" => provider} = params) do
    conn = conn
      |> merge_assigns(callback_url: Routes.delivery_url(conn, :link_account_callback, provider))

    PowAssent.Plug.callback_upsert(conn, provider, params, conn.assigns.callback_url)
    |> (fn {:ok, conn} ->
      %{current_user: current_user, current_author: current_author} = conn.assigns

      conn = case Accounts.link_user_author_account(current_user, current_author) do
        {:ok, _user} ->
          conn
          |> put_flash(:info, "Account '#{current_author.email}' is now linked")
        _ ->
          conn
          |> put_flash(:error, "Failed to link user and author accounts for '#{current_author.email}'")
      end

      {:ok, conn}
    end).()
    |> PowAssent.Phoenix.AuthorizationController.respond_callback()
  end

  def create_and_link_account(conn, _params) do
    # sign out current author account
    conn = conn
      |> use_pow_config(:author)
      |> Pow.Plug.delete()

    conn
    |> render_create_and_link_form()
  end

  def unauthorized(conn, _params) do
    render conn, "unauthorized.html"
  end

  def process_create_and_link_account_user(conn, %{"user" => user_params}) do
    conn
    |> use_pow_config(:author)
    |> Pow.Plug.create_user(user_params)
    |> case do
      {:ok, _user, conn} ->
        conn
        |> put_flash(:info, Pow.Phoenix.Controller.messages(conn, Pow.Phoenix.Messages).user_has_been_created(conn))
        |> redirect(to: Pow.Phoenix.Controller.routes(conn, Pow.Phoenix.Routes).after_registration_path(conn))

      {:error, changeset, conn} ->
        conn
        |> render_create_and_link_form(changeset: changeset)
    end
  end

  def render_create_and_link_form(conn, opts \\ []) do
    title = Keyword.get(opts, :title, "Create and Link Account")
    changeset = Keyword.get(opts, :changeset, Author.noauth_changeset(%Author{}))
    action = Keyword.get(opts, :action, Routes.delivery_path(conn, :process_create_and_link_account_user))
    sign_in_path = Keyword.get(opts, :sign_in_path, Routes.delivery_path(conn, :link_account))
    cancel_path = Keyword.get(opts, :cancel_path, Routes.delivery_path(conn, :index))

    conn
    |> assign(:title, title)
    |> assign(:changeset, changeset)
    |> assign(:action, action)
    |> assign(:sign_in_path, sign_in_path)
    |> assign(:cancel_path, cancel_path)
    |> assign(:link_account, true)
    |> put_view(OliWeb.Pow.RegistrationView)
    |> render("new.html")
  end

  def create_section(conn, %{"publication_id" => publication_id}) do
    lti_params = conn.assigns.lti_params
    user = conn.assigns.current_user

    issuer = lti_params["iss"]
    client_id = lti_params["aud"]
    deployment_id = lti_params["https://purl.imsglobal.org/spec/lti/claim/deployment_id"];
    {institution, _registration, _deployment} = Institutions.get_institution_registration_deployment(issuer, client_id, deployment_id)

    publication = Publishing.get_publication!(publication_id)

    {:ok, %Section{id: section_id}} = Sections.create_section(%{
      time_zone: institution.timezone,
      title: lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["title"],
      context_id: lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["id"],
      institution_id: institution.id,
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
    |> use_pow_config(:user)
    |> Pow.Plug.delete()
    |> redirect(to: Routes.delivery_path(conn, :index))
  end

end
