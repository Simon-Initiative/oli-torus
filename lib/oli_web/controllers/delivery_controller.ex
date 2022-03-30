defmodule OliWeb.DeliveryController do
  use OliWeb, :controller

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing
  alias Oli.Institutions
  alias Lti_1p3.Tool.{PlatformRoles, ContextRoles}
  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Repo
  alias Lti_1p3.Tool.Services.AGS
  alias Lti_1p3.Tool.Services.NRPS

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

  def select_project(conn, params) do
    user = conn.assigns.current_user
    lti_params = conn.assigns.lti_params
    issuer = lti_params["iss"]
    client_id = lti_params["aud"]
    deployment_id = lti_params["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]

    {institution, _registration, _deployment} =
      Institutions.get_institution_registration_deployment(issuer, client_id, deployment_id)

    render(conn, "select_project.html",
      author: user.author,
      sources: Publishing.retrieve_visible_sources(user, institution),
      remix: Map.get(params, "remix", "false")
    )
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

  def create_section(conn, %{"source_id" => source_id} = params) do
    lti_params = conn.assigns.lti_params
    user = conn.assigns.current_user

    # guard against creating a new section if one already exists
    Repo.transaction(fn ->
      case Sections.get_section_from_lti_params(lti_params) do
        nil ->
          issuer = lti_params["iss"]
          client_id = lti_params["aud"]
          deployment_id = lti_params["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]

          {institution, _registration, deployment} =
            Institutions.get_institution_registration_deployment(issuer, client_id, deployment_id)

          # create section, section resources and enroll instructor
          {:ok, section} =
            case source_id do
              "publication:" <> publication_id ->
                create_from_publication(
                  String.to_integer(publication_id),
                  user,
                  institution,
                  lti_params,
                  deployment
                )

              "product:" <> product_id ->
                create_from_product(
                  String.to_integer(product_id),
                  user,
                  institution,
                  lti_params,
                  deployment
                )
            end

          if is_remix?(params) do
            conn
            |> redirect(to: Routes.live_path(conn, OliWeb.Delivery.RemixSection, section.slug))
          else
            conn
            |> redirect(to: Routes.delivery_path(conn, :index))
          end

        section ->
          # a section already exists, redirect to index
          conn
          |> put_flash(:error, "Unable to create new section. This section already exists.")
          |> redirect_to_page_delivery(section)
      end
    end)
    |> case do
      {:ok, conn} ->
        conn

      {:error, error} ->
        {_error_id, error_msg} = log_error("Failed to create new section", error)

        conn
        |> put_flash(:error, error_msg)
        |> redirect(to: Routes.delivery_path(conn, :index))
    end
  end

  defp create_from_product(product_id, user, institution, lti_params, deployment) do
    blueprint = Oli.Delivery.Sections.get_section!(product_id)

    Repo.transaction(fn ->
      # calculate a cost, if an error, fallback to the amount in the blueprint
      # TODO: we may need to move this to AFTER a remix if the cost calculation factors
      # in the percentage project usage
      amount =
        case Oli.Delivery.Paywall.calculate_product_cost(blueprint, institution) do
          {:ok, amount} -> amount
          _ -> blueprint.amount
        end

      {:ok, section} =
        Oli.Delivery.Sections.Blueprint.duplicate(blueprint, %{
          type: :enrollable,
          timezone: institution.timezone,
          title: lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["title"],
          context_id: lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["id"],
          institution_id: institution.id,
          lti_1p3_deployment_id: deployment.id,
          blueprint_id: blueprint.id,
          amount: amount,
          grade_passback_enabled: AGS.grade_passback_enabled?(lti_params),
          line_items_service_url: AGS.get_line_items_url(lti_params),
          nrps_enabled: NRPS.nrps_enabled?(lti_params),
          nrps_context_memberships_url: NRPS.get_context_memberships_url(lti_params)
        })

      # Enroll this user with their proper roles (instructor)
      lti_roles = lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]
      context_roles = ContextRoles.get_roles_by_uris(lti_roles)
      Sections.enroll(user.id, section.id, context_roles)

      section
    end)
  end

  defp create_from_publication(publication_id, user, institution, lti_params, deployment) do
    publication = Publishing.get_publication!(publication_id)

    Repo.transaction(fn ->
      {:ok, section} =
        Sections.create_section(%{
          type: :enrollable,
          timezone: institution.timezone,
          title: lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["title"],
          context_id: lti_params["https://purl.imsglobal.org/spec/lti/claim/context"]["id"],
          institution_id: institution.id,
          base_project_id: publication.project_id,
          lti_1p3_deployment_id: deployment.id,
          grade_passback_enabled: AGS.grade_passback_enabled?(lti_params),
          line_items_service_url: AGS.get_line_items_url(lti_params),
          nrps_enabled: NRPS.nrps_enabled?(lti_params),
          nrps_context_memberships_url: NRPS.get_context_memberships_url(lti_params)
        })

      {:ok, %Section{id: section_id}} = Sections.create_section_resources(section, publication)

      # Enroll this user with their proper roles (instructor)
      lti_roles = lti_params["https://purl.imsglobal.org/spec/lti/claim/roles"]
      context_roles = ContextRoles.get_roles_by_uris(lti_roles)
      Sections.enroll(user.id, section_id, context_roles)

      section
    end)
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

  defp is_remix?(params) do
    case Map.get(params, "remix") do
      "true" ->
        true

      _ ->
        false
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
