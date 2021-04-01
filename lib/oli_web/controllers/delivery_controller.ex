defmodule OliWeb.DeliveryController do
  use OliWeb, :controller
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing

  alias Oli.Institutions
  alias Lti_1p3.Tool.ContextRoles
  alias Lti_1p3.Tool.PlatformRoles
  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias OliWeb.Common.LtiSession

  @allow_configure_section_roles [
    PlatformRoles.get_role(:system_administrator),
    PlatformRoles.get_role(:institution_administrator),
    PlatformRoles.get_role(:institution_instructor),
    ContextRoles.get_role(:context_administrator),
    ContextRoles.get_role(:context_instructor)
  ]

  plug Oli.Plugs.RegistrationCaptcha when action in [:process_create_and_link_account_user]

  def index(conn, _params) do
    user = conn.assigns.current_user
    lti_params = conn.assigns.lti_params
    section = Sections.get_section_from_lti_params(lti_params)

    lti_roles = lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]
    context_roles = ContextRoles.get_roles_by_uris(lti_roles)

    platform_roles = PlatformRoles.get_roles_by_uris(lti_roles)
    roles = MapSet.new(context_roles ++ platform_roles)
    allow_configure_section_roles = MapSet.new(@allow_configure_section_roles)

    # allow section configuration if user has any of the allowed roles
    allow_configure_section = (MapSet.intersection(roles, allow_configure_section_roles) |> MapSet.size()) > 0

    open_and_free_user? = case lti_params["https://oli.cmu.edu/session"] do
      %{"open_and_free" => true} -> true
      _ -> false
    end

    if open_and_free_user? do
      render_open_and_free_index(conn, user)
    else
      case {user.author, section} do
        # author account has not been linked
        {nil, nil} when allow_configure_section ->
          render_getting_started(conn)

        # section has not been configured
        {author, nil} when allow_configure_section ->
          render_configure_section(conn, author)

        {_author, nil} ->
          render_course_not_configured(conn)

        # section has been configured
        {_author, section} ->
          redirect_to_page_delivery(conn, section)
      end
    end
  end

  defp render_open_and_free_index(conn, user) do
    sections = Sections.list_user_open_and_free_sections(user)

    IO.inspect sections

    render(conn, "open_and_free_index.html", sections: sections)
  end

  defp render_course_not_configured(conn) do
    render(conn, "course_not_configured.html")
  end


  defp render_getting_started(conn) do
    render(conn, "getting_started.html")
  end

  defp render_configure_section(conn, author) do
    lti_params = conn.assigns.lti_params
    issuer = lti_params["iss"]
    client_id = lti_params["aud"]
    deployment_id = lti_params["https://purl.imsglobal.org/spec/lti/claim/deployment_id"];
    {institution, _registration, _deployment} = Institutions.get_institution_registration_deployment(issuer, client_id, deployment_id)

    publications = Publishing.available_publications(author, institution)
    my_publications = publications |> Enum.filter(fn p -> p.published end)

    render(conn, "configure_section.html", author: author, my_publications: my_publications)
  end

  defp redirect_to_page_delivery(conn, section) do
    redirect(conn, to: Routes.page_delivery_path(conn, :index, section.slug))
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
    {institution, _registration, deployment} = Institutions.get_institution_registration_deployment(issuer, client_id, deployment_id)

    publication = Publishing.get_publication!(publication_id)

    {:ok, %Section{id: section_id, slug: section_slug}} = Sections.create_section(%{
      time_zone: institution.timezone,
      title: lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["title"],
      context_id: lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["id"],
      institution_id: institution.id,
      project_id: publication.project_id,
      publication_id: publication_id,
      lti_1p3_deployment_id: deployment.id,
    })

    # Enroll this user with their proper roles (instructor)
    lti_roles = lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]
    context_roles = ContextRoles.get_roles_by_uris(lti_roles)
    Sections.enroll(user.id, section_id, context_roles)

    # set the lti_params_key for the new section to the current user's lti_params_key
    lti_params_key = LtiSession.get_user_params(conn)
    LtiSession.put_section_params(conn, section_slug, lti_params_key)

    conn
    |> redirect(to: Routes.delivery_path(conn, :index))
  end

  def signout(conn, _params) do
    conn
    |> use_pow_config(:user)
    |> Pow.Plug.delete()
    |> redirect(to: Routes.delivery_path(conn, :index))
  end

  def login(conn, %{"sub" => sub}) do
    with user when not is_nil(user) <- Accounts.get_user_by(sub: sub)
    do
      conn
      |> LtiSession.put_user_params(user.sub)
      |> OliWeb.Pow.PowHelpers.use_pow_config(:user)
      |> Pow.Plug.create(user)
      |> redirect(to: Routes.delivery_path(conn, :index))
    else
      _ ->
        render conn, "unauthorized.html"
    end
  end

end
