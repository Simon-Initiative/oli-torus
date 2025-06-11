defmodule OliWeb.DeliveryController do
  use OliWeb, :controller
  use OliWeb, :verified_routes

  alias Lti_1p3.Roles.{PlatformRoles, ContextRoles}
  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.Analytics.DataTables.DataTable
  alias Oli.Delivery
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.EnrollmentBrowseOptions
  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Lti.LtiParams
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.UserAuth
  alias OliWeb.Common.Params
  alias OliWeb.Delivery.InstructorDashboard.Helpers
  alias OliWeb.Delivery.Student.Utils

  require Logger

  @allow_configure_section_roles [
    PlatformRoles.get_role(:system_administrator),
    PlatformRoles.get_role(:institution_administrator),
    ContextRoles.get_role(:context_administrator),
    ContextRoles.get_role(:context_instructor)
  ]

  @doc """
  This is the default entry point for delivery users. It will redirect to the appropriate page based
  on whether the user is an independent learner or an LTI user.

  If the user is an independent learner, they will be redirected to the student workspace.

  If the user is an LTI user, the user's roles will be checked to determine if they are allowed to
  configure the section. If they are allowed to configure the section, they will be redirected to
  the instructor dashboard. If they are not allowed to configure the section, the student will be
  redirected to the page delivery.
  """
  def index(conn, _params) do
    user = conn.assigns.current_user

    with false <- user.independent_learner,
         %LtiParams{params: lti_params} <- LtiParams.get_latest_user_lti_params(user.id) do
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
        nil when allow_configure_section ->
          render_getting_started(conn)

        nil ->
          render_course_not_configured(conn)

        section when allow_configure_section ->
          redirect_to_instructor_dashboard(conn, section)

        # section has been configured
        section ->
          redirect_to_page_delivery(conn, section)
      end
    else
      _ ->
        redirect(conn, to: ~p"/workspaces/student")
    end
  end

  defp render_course_not_configured(conn) do
    render(conn, "course_not_configured.html")
  end

  defp render_getting_started(conn) do
    render(conn, "getting_started.html")
  end

  defp redirect_to_page_delivery(conn, section) do
    redirect(conn,
      to: ~p"/sections/#{section.slug}"
    )
  end

  defp redirect_to_instructor_dashboard(conn, section) do
    redirect(conn,
      to: ~p"/sections/#{section.slug}/manage"
    )
  end

  def show_research_consent(conn, params) do
    user = conn.assigns.current_user
    user_return_to = params["user_return_to"]

    institution = Institutions.get_institution_by_lti_user(user)

    case conn.assigns.current_user do
      nil ->
        conn
        |> put_flash(:error, "User not found")
        |> redirect(to: Routes.delivery_path(conn, :index))

      # Direct delivery users
      %User{independent_learner: true} = user ->
        case Delivery.get_system_research_consent_form_setting() do
          :oli_form ->
            conn
            |> assign(:research_opt_out, user_research_opt_out?(user))
            |> assign(:user_return_to, user_return_to)
            |> render("research_consent.html")

          _ ->
            conn
            |> put_flash(:error, "Research consent is not enabled for this platform")
            |> redirect(to: Routes.delivery_path(conn, :index))
        end

      # LTI users
      user ->
        case institution do
          %Institution{research_consent: :oli_form} ->
            conn
            |> assign(:research_opt_out, user_research_opt_out?(user))
            |> assign(:user_return_to, user_return_to)
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

  def research_consent(conn, %{"consent" => consent} = params) do
    user = conn.assigns.current_user

    redirect_to = params["user_return_to"] || ~p"/sections"

    case Accounts.update_user(user, %{research_opt_out: consent !== "true"}) do
      {:ok, _} ->
        conn
        |> redirect(to: redirect_to)

      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to update research consent preference")
        |> redirect(to: ~p"/research_consent")
    end
  end

  def show_enroll(conn, params) do
    section = conn.assigns.section
    from_invitation_link? = params["from_invitation_link?"] || false
    create_guest = false

    with {:available, section} <- Sections.available?(section),
         {:ok, user} <- current_or_guest_user(conn, section.requires_enrollment, create_guest),
         {:enrolled?, false} <- {:enrolled?, Sections.is_enrolled?(user.id, section.slug)} do
      render(conn, "enroll.html",
        section: Oli.Repo.preload(section, [:base_project]),
        from_invitation_link?: from_invitation_link?,
        auto_enroll_as_guest: params["auto_enroll_as_guest"] || false
      )
    else
      {:unavailable, reason} ->
        render_section_unavailable(conn, reason)

      {:redirect, :enroll} ->
        render(conn, "enroll.html",
          section: Oli.Repo.preload(section, [:base_project]),
          from_invitation_link?: from_invitation_link?,
          auto_enroll_as_guest: params["auto_enroll_as_guest"] || false
        )

      # redirect to course index if user is already signed in and enrolled
      {:enrolled?, true} ->
        redirect(conn, to: ~p"/sections/#{section.slug}")

      # guest user cannot access courses that require enrollment
      {:redirect, nil} ->
        params = [
          section: section.slug,
          from_invitation_link?: true,
          request_path: ~p"/sections/#{section.slug}/enroll"
        ]

        redirect(conn,
          to: ~p"/users/log_in?#{params}"
        )
    end
  end

  def process_enroll(conn, params) do
    g_recaptcha_response = Map.get(params, "g-recaptcha-response", "")
    create_guest = true

    if Oli.Utils.LoadTesting.enabled?() or recaptcha_verified?(g_recaptcha_response) do
      with {:available, section} <- Sections.available?(conn.assigns.section),
           {:ok, user} <- current_or_guest_user(conn, section.requires_enrollment, create_guest),
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
          |> UserAuth.create_session(user)
          |> redirect(to: ~p"/sections/#{section.slug}")
        end
      else
        {:redirect, nil} ->
          # guest user cant access courses that require enrollment
          redirect_path =
            "/users/log_in?request_path=#{Routes.delivery_path(conn, :show_enroll, conn.assigns.section.slug)}"

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

  defp current_or_guest_user(conn, requires_enrollment, create_guest) do
    case conn.assigns.current_user do
      nil ->
        if create_guest do
          if requires_enrollment, do: {:redirect, nil}, else: Accounts.create_guest_user()
        else
          if requires_enrollment, do: {:redirect, nil}, else: {:redirect, :enroll}
        end

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
        students = Helpers.get_students(section, :context_learner)

        contents =
          Enum.map(
            students,
            &%{
              status: parse_enrollment_status(&1.enrollment_status),
              name: OliWeb.Common.Utils.name(&1),
              email: &1.email,
              lms_id: &1.sub,
              last_interaction: &1.last_interaction,
              progress: convert_to_percentage(&1),
              overall_proficiency: &1.overall_proficiency,
              requires_payment: Map.get(&1, :requires_payment, "N/A")
            }
          )
          |> sort_data()
          |> DataTable.new()
          |> DataTable.headers(
            status: "Status",
            name: "Name",
            email: "Email",
            lms_id: "LMS ID",
            last_interaction: "Last Interaction",
            progress: "Progress (Pct)",
            overall_proficiency: "Proficiency",
            requires_payment: "Requires Payment"
          )
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
          |> Enum.map(fn objective ->
            %{
              objective: objective.objective,
              subobjective: objective.subobjective,
              student_proficiency_obj: objective.student_proficiency_obj,
              student_proficiency_subobj: objective.student_proficiency_subobj
            }
          end)
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
            |> Map.put(:student_id, enrollment.user.id)
            |> Map.put(:student_lms_id, enrollment.user.sub)
            |> Map.put(:student_family_name, enrollment.user.family_name)
            |> Map.put(:student_given_name, enrollment.user.given_name)
            |> Map.put(:student_email, enrollment.user.email)
          end)
          |> DataTable.new()
          |> DataTable.headers(
            [
              :student_id,
              :student_lms_id,
              :student_family_name,
              :student_given_name,
              :student_email
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

  defp sort_data(results) do
    Enum.sort_by(results, &{&1.status, &1.name, &1.email})
  end

  defp convert_to_percentage(%{progress: nil}), do: 0

  defp convert_to_percentage(%{progress: progress}) when progress <= 1.0 do
    Utils.parse_score(progress * 100)
  end

  defp convert_to_percentage(%{progress: _progress} = user_data) do
    Logger.error("Progress exceeds 1.0 threshold: #{inspect(user_data)}")
    nil
  end

  defp parse_enrollment_status(:enrolled), do: "Enrolled"
  defp parse_enrollment_status(:suspended), do: "Suspended"
  defp parse_enrollment_status(:pending_confirmation), do: "Pending confirmation"
  defp parse_enrollment_status(:rejected), do: "Rejected invitation"
  defp parse_enrollment_status(_status), do: "Unkknown"
end
