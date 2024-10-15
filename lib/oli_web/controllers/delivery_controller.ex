defmodule OliWeb.DeliveryController do
  use OliWeb, :controller
  use OliWeb, :verified_routes

  alias Lti_1p3.Tool.{PlatformRoles, ContextRoles}
  alias Oli.Accounts
  alias Oli.Accounts.{User, Author}
  alias Oli.Analytics.DataTables.DataTable
  alias Oli.Delivery
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.EnrollmentBrowseOptions
  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Lti.LtiParams
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.Params
  alias OliWeb.Delivery.InstructorDashboard.Helpers

  require Logger

  @allow_configure_section_roles [
    PlatformRoles.get_role(:system_administrator),
    PlatformRoles.get_role(:institution_administrator),
    ContextRoles.get_role(:context_administrator),
    ContextRoles.get_role(:context_instructor)
  ]

  plug(Oli.Plugs.RegistrationCaptcha when action in [:process_create_and_link_account_user])

  def instructor_dashboard(conn, %{"section_slug" => section_slug}) do
    # redirect to live view
    redirect(conn,
      to:
        Routes.live_path(
          conn,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section_slug,
          "overview"
        )
    )
  end

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

      section when allow_configure_section ->
        redirect_to_instructor_dashboard(conn, section)

      # section has been configured
      section ->
        {institution, _registration, _deployment} =
          Institutions.get_institution_registration_deployment(
            lti_params["iss"],
            LtiParams.peek_client_id(lti_params),
            lti_params["https://purl.imsglobal.org/spec/lti/claim/deployment_id"]
          )

        if institution.research_consent != :no_form and is_nil(user.research_opt_out) do
          render_research_consent(conn, ~p"/sections/#{section.slug}")
        else
          redirect_to_page_delivery(conn, section)
        end
    end
  end

  defp render_course_not_configured(conn) do
    render(conn, "course_not_configured.html")
  end

  defp render_getting_started(conn) do
    render(conn, "getting_started.html")
  end

  defp render_research_consent(conn, redirect_url) do
    case conn.assigns.current_user do
      nil ->
        conn
        |> put_flash(:error, "User not found")
        |> redirect(to: Routes.delivery_path(conn, :index))

      # Direct delivery users
      %User{independent_learner: true} = user ->
        case Delivery.get_research_consent_form_setting() do
          :oli_form ->
            conn
            |> assign(:research_opt_out, user_research_opt_out?(user))
            |> assign(:redirect_url, redirect_url)
            |> render("research_consent.html")

          _ ->
            conn
            |> put_flash(:error, "Research consent is not enabled for this platform")
            |> redirect(to: Routes.delivery_path(conn, :index))
        end

      # LTI users
      user ->
        # check institution research consent setting
        institution = Institutions.get_institution_by_lti_user(user)

        case institution do
          %Institution{research_consent: :oli_form} ->
            conn
            |> assign(:research_opt_out, user_research_opt_out?(user))
            |> assign(:redirect_url, redirect_url)
            |> render("research_consent.html")

          _ ->
            conn
            |> put_flash(:error, "Research consent is not enabled for your institution")
            |> redirect(to: Routes.delivery_path(conn, :index))
        end
    end
  end

  defp user_research_opt_out?(%User{research_opt_out: true}), do: true
  defp user_research_opt_out?(_), do: false

  defp redirect_to_page_delivery(conn, section) do
    redirect(conn,
      to: ~p"/sections/#{section.slug}"
    )
  end

  defp redirect_to_instructor_dashboard(conn, section) do
    redirect(conn,
      to: ~p"/sections/#{section.slug}/instructor_dashboard/manage"
    )
  end

  def show_research_consent(conn, _params) do
    user = conn.assigns.current_user

    redirect_url =
      case user do
        %User{independent_learner: true} ->
          case Map.get(conn.assigns, :section) do
            nil -> ~p"/sections"
            section -> ~p"/sections/#{section.slug}"
          end

        _ ->
          ~p"/course"
      end

    conn
    |> assign(:research_opt_out, user.research_opt_out)
    |> render_research_consent(redirect_url)
  end

  def research_consent(conn, %{"consent" => consent, "redirect_url" => redirect_url}) do
    user = conn.assigns.current_user

    case Accounts.update_user(user, %{research_opt_out: consent !== "true"}) do
      {:ok, _} ->
        conn
        |> redirect(to: redirect_url)

      {:error, _} ->
        conn
        |> put_flash(:error, "Unable to persist research consent option")
        |> redirect(to: redirect_url)
    end
  end

  def link_account(conn, _params) do
    # sign out current author account
    conn
    |> delete_pow_user(:author)
    |> render_link_account_form()
  end

  def render_user_register_form(conn, changeset) do
    # The learner/educator register form.
    conn
    |> assign(:changeset, changeset)
    |> assign(:action, Routes.pow_registration_path(conn, :create))
    |> assign(:sign_in_path, ~p"/users/log_in")
    |> assign(:cancel_path, Routes.delivery_path(conn, :index))
    |> Phoenix.Controller.put_view(OliWeb.Pow.RegistrationHTML)
    |> Phoenix.Controller.render("new.html")
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
    |> put_view(OliWeb.Pow.SessionHTML)
    |> Phoenix.Controller.render("new.html")
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
    conn
    |> delete_pow_user(:author)
    |> render_create_and_link_form()
  end

  @spec process_create_and_link_account_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def process_create_and_link_account_user(conn, %{"user" => user_params}) do
    %{current_user: current_user} = conn.assigns

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

        Pow.Phoenix.Controller.routes(conn, Pow.Phoenix.Routes).after_registration_path(conn)
        conn = Pow.Plug.Session.do_delete(conn, get_pow_config(:author))

        if current_user.independent_learner do
          redirect(conn, to: Routes.live_path(conn, OliWeb.Delivery.OpenAndFreeIndex))
        else
          redirect(conn, to: Routes.delivery_path(conn, :index))
        end

      {:error, changeset, conn} ->
        conn
        |> render_create_and_link_form(changeset: changeset)
    end
  end

  def render_author_register_form(conn, opts \\ []) do
    # This is currently used when an author is registering, and they failed the captcha. They are sent here from
    # Oli.Plugs.RegistrationCaptcha.render_captcha_error
    changeset = Keyword.get(opts, :changeset, Author.noauth_changeset(%Author{}))

    action =
      Keyword.get(
        opts,
        :action,
        Routes.authoring_pow_registration_path(conn, :create)
      )

    sign_in_path = Keyword.get(opts, :sign_in_path, Routes.authoring_pow_session_path(conn, :new))
    cancel_path = Keyword.get(opts, :cancel_path, Routes.delivery_path(conn, :index))

    conn
    |> assign(:changeset, changeset)
    |> assign(:action, action)
    |> assign(:sign_in_path, sign_in_path)
    |> assign(:cancel_path, cancel_path)
    |> put_view(OliWeb.Pow.RegistrationHTML)
    |> Phoenix.Controller.render("new.html")
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
    |> put_view(OliWeb.Pow.RegistrationHTML)
    |> Phoenix.Controller.render("new.html")
  end

  def show_enroll(conn, params) do
    case Sections.available?(conn.assigns.section) do
      {:available, section} ->
        # redirect to course index if user is already signed in and enrolled
        with {:ok, user} <- current_or_guest_user(conn, section.requires_enrollment),
             true <- Sections.is_enrolled?(user.id, section.slug) do
          redirect(conn,
            to: ~p"/sections/#{section.slug}"
          )
        else
          {:redirect, nil} ->
            # guest user cant access courses that require enrollment
            login_params = [
              section: section.slug,
              from_invitation_link?: params["from_invitation_link?"] || false
            ]

            redirect_path =
              ~p"/users/log_in?#{login_params}"

            conn
            |> redirect(to: redirect_path)

          _ ->
            section = Oli.Repo.preload(section, [:base_project])

            render(conn, "enroll.html",
              section: section,
              from_invitation_link?: params["from_invitation_link?"] || false,
              auto_enroll_as_guest: params["auto_enroll_as_guest"] || false
            )
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
           {:ok, user} <- current_or_guest_user(conn, section.requires_enrollment),
           user <- Repo.preload(user, [:platform_roles]) do
        if Sections.is_enrolled?(user.id, section.slug) do
          redirect(conn,
            to: ~p"/sections/#{section.slug}"
          )
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
          |> create_pow_user(:user, user)
          |> redirect(to: ~p"/sections/#{section.slug}")
        end
      else
        {:redirect, nil} ->
          # guest user cant access courses that require enrollment
          redirect_path =
            "/session/new?request_path=#{Routes.delivery_path(conn, :show_enroll, conn.assigns.section.slug)}"

          conn
          |> put_flash(
            :error,
            "Cannot enroll guest users in a course section that requires enrollment"
          )
          |> redirect(to: redirect_path)

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

  defp current_or_guest_user(conn, requires_enrollment) do
    case conn.assigns.current_user do
      nil ->
        if requires_enrollment, do: {:redirect, nil}, else: Accounts.create_guest_user()

      %User{guest: true} = guest ->
        if requires_enrollment, do: {:redirect, nil}, else: {:ok, guest}

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

  def download_course_content_info(conn, %{"section_slug" => slug} = params) do
    case Oli.Delivery.Sections.get_section_by_slug(slug) do
      nil ->
        Phoenix.Controller.redirect(conn,
          to: Routes.static_page_path(OliWeb.Endpoint, :not_found)
        )

      section ->
        {_total_count, containers_with_metrics} = Helpers.get_containers(section, async: false)

        container_filter_by =
          Params.get_atom_param(
            params,
            "container_filter_by",
            [:modules, :units, :pages],
            :units
          )

        filter_fn = fn container ->
          case container_filter_by do
            :units ->
              container.numbering_level == 1

            :modules ->
              container.numbering_level == 2

            _ ->
              true
          end
        end

        contents =
          containers_with_metrics
          |> Enum.filter(filter_fn)
          |> Enum.map(
            &%{
              title: &1.title,
              progress: &1.progress,
              student_proficiency: &1.student_proficiency
            }
          )
          |> DataTable.new()
          |> DataTable.headers([:title, :progress, :student_proficiency])
          |> DataTable.to_csv_content()

        conn
        |> send_download({:binary, contents},
          filename: "#{slug}_course_content.csv"
        )
    end
  end

  def download_students_progress(conn, %{"section_slug" => slug}) do
    case Oli.Delivery.Sections.get_section_by_slug(slug) do
      nil ->
        Phoenix.Controller.redirect(conn,
          to: Routes.static_page_path(OliWeb.Endpoint, :not_found)
        )

      section ->
        students = Helpers.get_students(section)

        contents =
          students
          |> Enum.map(
            &%{
              name: &1.name,
              email: &1.email,
              last_interaction: &1.last_interaction,
              progress: &1.progress,
              overall_proficiency: &1.overall_proficiency,
              requires_payment: Map.get(&1, :requires_payment, "N/A")
            }
          )
          |> DataTable.new()
          |> DataTable.headers([
            :name,
            :email,
            :last_interaction,
            :progress,
            :overall_proficiency,
            :requires_payment
          ])
          |> DataTable.to_csv_content()

        conn
        |> send_download({:binary, contents},
          filename: "#{slug}_students.csv"
        )
    end
  end

  def download_learning_objectives(conn, %{"section_slug" => slug}) do
    case Oli.Delivery.Sections.get_section_by_slug(slug) do
      nil ->
        Phoenix.Controller.redirect(conn,
          to: Routes.static_page_path(OliWeb.Endpoint, :not_found)
        )

      section ->
        contents =
          Sections.get_objectives_and_subobjectives(section)
          |> Enum.map(
            &%{
              objective: &1.objective,
              subojective: &1.subobjective,
              student_proficiency_obj: &1.student_proficiency_obj,
              student_proficiency_subobj: &1.student_proficiency_subobj
            }
          )
          |> DataTable.new()
          |> DataTable.headers([
            :objective,
            :subojective,
            :student_proficiency_obj,
            :student_proficiency_subobj
          ])
          |> DataTable.to_csv_content()

        conn
        |> send_download({:binary, contents},
          filename: "#{slug}_learning_objectives.csv"
        )
    end
  end

  def download_quiz_scores(conn, %{"section_slug" => slug}) do
    case Oli.Delivery.Sections.get_section_by_slug(slug) do
      nil ->
        Phoenix.Controller.redirect(conn,
          to: Routes.static_page_path(OliWeb.Endpoint, :not_found)
        )

      section ->
        enrollments =
          Sections.browse_enrollments(
            section,
            %Paging{offset: 0, limit: nil},
            %Sorting{direction: :desc, field: :name},
            %EnrollmentBrowseOptions{
              text_search: "",
              is_student: true,
              is_instructor: false
            }
          )

        hierarchy = Oli.Publishing.DeliveryResolver.full_hierarchy(section.slug)

        graded_pages =
          hierarchy
          |> Oli.Delivery.Hierarchy.flatten()
          |> Enum.filter(fn node -> node.revision.graded end)
          |> Enum.map(fn node -> node.revision end)

        resource_accesses = fetch_resource_accesses(enrollments, section)

        by_user =
          Enum.reduce(resource_accesses, %{}, fn ra, m ->
            case Map.has_key?(m, ra.user_id) do
              true ->
                user = Map.get(m, ra.user_id)
                Map.put(m, ra.user_id, Map.put(user, ra.resource_id, ra))

              false ->
                Map.put(m, ra.user_id, Map.put(%{}, ra.resource_id, ra))
            end
          end)

        pages = Enum.map(graded_pages, &{&1.resource_id, &1.title})

        contents =
          Enum.map(enrollments, fn user ->
            Map.get(by_user, user.id, %{})
            |> Map.merge(%{user: user, id: user.id, section: section})
          end)
          |> Enum.map(fn enrollment ->
            Enum.reduce(pages, %{}, fn {page_id, page_title}, acc ->
              page_enrollment = Map.get(enrollment, page_id, %{})
              score = Map.get(page_enrollment, :score)
              out_of = Map.get(page_enrollment, :out_of)
              Map.put(acc, page_title, safe_score(score, out_of))
            end)
            |> Map.put(:student, OliWeb.Common.Utils.name(enrollment.user))
          end)
          |> DataTable.new()
          |> DataTable.headers(
            [
              :student
            ] ++ Enum.map(pages, &elem(&1, 1))
          )
          |> DataTable.to_csv_content()

        conn
        |> send_download({:binary, contents},
          filename: "#{slug}_quiz_scores.csv"
        )
    end
  end

  defp safe_score(score, out_of) do
    not_finished_msg = "Not finished"

    case {score, out_of} do
      {nil, _} -> not_finished_msg
      {_, nil} -> "#{score / 1 * 100}%"
      {_, 0} -> "#{score / 1 * 100}%"
      _ -> "#{score / out_of * 100}%"
    end
  end

  defp fetch_resource_accesses(enrollments, section) do
    student_ids = Enum.map(enrollments, fn user -> user.id end)

    Oli.Delivery.Attempts.Core.get_graded_resource_access_for_context(
      section.id,
      student_ids
    )
  end
end
