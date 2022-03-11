defmodule OliWeb.DeliveryController do
  use OliWeb, :controller

  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.{PlatformRoles, ContextRoles}
  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Repo

  import Oli.Utils

  require Logger

  @allow_configure_section_roles [
    PlatformRoles.get_role(:system_administrator),
    PlatformRoles.get_role(:institution_administrator),
    PlatformRoles.get_role(:institution_instructor),
    ContextRoles.get_role(:context_administrator),
    ContextRoles.get_role(:context_instructor)
  ]

  plug(Oli.Plugs.RegistrationCaptcha when action in [:process_create_and_link_account_user])

  def index(conn, _params) do
    user = conn.assigns.current_user
    lti_params = conn.assigns.lti_params

    lti_roles = lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]
    context_roles = ContextRoles.get_roles_by_uris(lti_roles)
    platform_roles = PlatformRoles.get_roles_by_uris(lti_roles)
    roles = MapSet.new(context_roles ++ platform_roles)
    allow_configure_section_roles = MapSet.new(@allow_configure_section_roles)

    # allow section configuration if user has any of the allowed roles
    allow_configure_section =
      MapSet.intersection(roles, allow_configure_section_roles) |> MapSet.size() > 0

    section = Sections.get_section_from_lti_params(lti_params)

    case section do
      # author account has not been linked
      nil when allow_configure_section ->
        render_getting_started(conn)

      nil ->
        render_course_not_configured(conn)

      # section has been configured
      section ->
        if user.research_opt_out === nil do
          render_research_consent(conn)
        else
          redirect_to_page_delivery(conn, section)
        end
    end
  end

  def open_and_free_index(conn, _params) do
    user = conn.assigns.current_user

    sections = Sections.list_user_open_and_free_sections(user)

    render(conn, "open_and_free_index.html", sections: sections, user: user)
  end

  defp render_course_not_configured(conn) do
    render(conn, "course_not_configured.html")
  end

  defp render_getting_started(conn) do
    render(conn, "getting_started.html")
  end

  defp render_research_consent(conn) do
    conn
    |> assign(:opt_out, nil)
    |> render("research_consent.html")
  end

  defp redirect_to_page_delivery(conn, section) do
    redirect(conn, to: Routes.page_delivery_path(conn, :index, section.slug))
  end

  def research_consent(conn, %{"consent" => consent}) do
    user = conn.assigns.current_user
    lti_params = conn.assigns.lti_params
    section = Sections.get_section_from_lti_params(lti_params)

    case Accounts.update_user(user, %{research_opt_out: consent !== "true"}) do
      {:ok, _} ->
        redirect_to_page_delivery(conn, section)

      {:error, _} ->
        conn
        |> put_flash(:error, "Unable to persist research consent option")
        |> redirect_to_page_delivery(section)
    end
  end

  def link_account(conn, _params) do
    # sign out current author account
    conn =
      conn
      |> use_pow_config(:author)
      |> Pow.Plug.delete()

    conn
    |> render_link_account_form()
  end

  def render_link_account_form(conn, opts \\ []) do
    title = Keyword.get(opts, :title, "Link Existing Account")
    changeset = Keyword.get(opts, :changeset, Author.noauth_changeset(%Author{}))
    action = Keyword.get(opts, :action, Routes.delivery_path(conn, :process_link_account_user))

    create_account_path =
      Keyword.get(
        opts,
        :create_account_path,
        Routes.delivery_path(conn, :create_and_link_account)
      )

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
    conn =
      conn
      |> merge_assigns(
        callback_url: Routes.authoring_delivery_url(conn, :link_account_callback, provider)
      )

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
        |> put_flash(
          :info,
          Pow.Phoenix.Controller.messages(conn, Pow.Phoenix.Messages).signed_in(conn)
        )
        |> redirect(
          to: Pow.Phoenix.Controller.routes(conn, Pow.Phoenix.Routes).after_sign_in_path(conn)
        )

      {:error, conn} ->
        conn
        |> put_flash(
          :error,
          Pow.Phoenix.Controller.messages(conn, Pow.Phoenix.Messages).invalid_credentials(conn)
        )
        |> render_link_account_form(
          changeset: PowAssent.Plug.change_user(conn, %{}, author_params)
        )
    end
  end

  def link_account_callback(conn, %{"provider" => provider} = params) do
    conn =
      conn
      |> merge_assigns(
        callback_url: Routes.authoring_delivery_url(conn, :link_account_callback, provider)
      )

    PowAssent.Plug.callback_upsert(conn, provider, params, conn.assigns.callback_url)
    |> (fn {:ok, conn} ->
          %{current_user: current_user, current_author: current_author} = conn.assigns

          conn =
            case Accounts.link_user_author_account(current_user, current_author) do
              {:ok, _user} ->
                conn
                |> put_flash(:info, "Account '#{current_author.email}' is now linked")

              _ ->
                conn
                |> put_flash(
                  :error,
                  "Failed to link user and author accounts for '#{current_author.email}'"
                )
            end

          {:ok, conn}
        end).()
    |> PowAssent.Phoenix.AuthorizationController.respond_callback()
  end

  def create_and_link_account(conn, _params) do
    # sign out current author account
    conn =
      conn
      |> use_pow_config(:author)
      |> Pow.Plug.delete()

    conn
    |> render_create_and_link_form()
  end

  def process_create_and_link_account_user(conn, %{"user" => user_params}) do
    conn
    |> use_pow_config(:author)
    |> Pow.Plug.create_user(user_params)
    |> case do
      {:ok, _user, conn} ->
        conn
        |> put_flash(
          :info,
          Pow.Phoenix.Controller.messages(conn, Pow.Phoenix.Messages).user_has_been_created(conn)
        )
        |> redirect(
          to:
            Pow.Phoenix.Controller.routes(conn, Pow.Phoenix.Routes).after_registration_path(conn)
        )

      {:error, changeset, conn} ->
        conn
        |> render_create_and_link_form(changeset: changeset)
    end
  end

  def render_create_and_link_form(conn, opts \\ []) do
    title = Keyword.get(opts, :title, "Create and Link Account")
    changeset = Keyword.get(opts, :changeset, Author.noauth_changeset(%Author{}))

    action =
      Keyword.get(
        opts,
        :action,
        Routes.delivery_path(conn, :process_create_and_link_account_user)
      )

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

  def signin(conn, %{"section" => section}) do
    conn
    |> use_pow_config(:user)
    |> Pow.Plug.delete()
    |> redirect(to: Routes.pow_session_path(conn, :new, section: section))
  end

  def create_account(conn, %{"section" => section}) do
    conn
    |> use_pow_config(:user)
    |> Pow.Plug.delete()
    |> redirect(to: Routes.pow_registration_path(conn, :new, section: section))
  end

  def show_enroll(conn, _params) do
    case Sections.available?(conn.assigns.section) do
      {:available, section} ->
        # redirect to course index if user is already signed in and enrolled
        with {:ok, user} <- conn.assigns.current_user |> trap_nil,
             true <- Sections.is_enrolled?(user.id, section.slug) do
          redirect(conn, to: Routes.page_delivery_path(conn, :index, section.slug))
        else
          _ ->
            section = Oli.Repo.preload(section, [:base_project])

            render(conn, "enroll.html", section: section)
        end

      {:unavailable, reason} ->
        conn
        |> render_section_unavailable(reason)
    end
  end

  def process_enroll(conn, params) do
    g_recaptcha_response = Map.get(params, "g-recaptcha-response", "")

    if Oli.Utils.LoadTesting.enabled?() or recaptcha_verified?(g_recaptcha_response) do
      with {:available, section} <- Sections.available?(conn.assigns.section),
           {:ok, user} <- current_or_guest_user(conn),
           user <- Repo.preload(user, [:platform_roles]) do
        if Sections.is_enrolled?(user.id, section.slug) do
          redirect(conn, to: Routes.page_delivery_path(conn, :index, section.slug))
        else
          Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

          Accounts.update_user_platform_roles(
            user,
            Lti_1p3.DataProviders.EctoProvider.Marshaler.from(user.platform_roles)
            |> MapSet.new()
            |> MapSet.put(PlatformRoles.get_role(:institution_learner))
            |> MapSet.to_list()
          )

          conn
          |> OliWeb.Pow.PowHelpers.use_pow_config(:user)
          |> Pow.Plug.create(user)
          |> redirect(to: Routes.page_delivery_path(conn, :index, section.slug))
        end
      else
        _error ->
          render(conn, "enroll.html", error: "Something went wrong, please try again")
      end
    else
      render(conn, "enroll.html", error: "ReCaptcha failed, please try again")
    end
  end

  def enroll_independent(conn, %{"section_invite_slug" => _invite_slug} = params),
    do: show_enroll(conn, params)

  defp recaptcha_verified?(g_recaptcha_response) do
    Oli.Utils.Recaptcha.verify(g_recaptcha_response) == {:success, true}
  end

  defp current_or_guest_user(conn) do
    case conn.assigns.current_user do
      nil ->
        Accounts.create_guest_user()

      user ->
        {:ok, user}
    end
  end

  defp render_section_unavailable(conn, reason) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> put_status(403)
    |> render("section_unavailable.html", reason: reason)
    |> halt()
  end
end
