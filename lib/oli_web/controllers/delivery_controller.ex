defmodule OliWeb.DeliveryController do
  use OliWeb, :controller
  use OliWeb, :verified_routes

  alias Lti_1p3.Roles.{PlatformRoles, ContextRoles}
  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.Authoring.Course
  alias Oli.Analytics.DataTables.DataTable
  alias Oli.Dashboard.Oracle.Result
  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.Snapshot.Assembler
  alias Oli.Dashboard.Snapshot.Projections
  alias Oli.Delivery
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.EnrollmentBrowseOptions
  alias Oli.InstructorDashboard.DataSnapshot.CsvExport
  alias Oli.InstructorDashboard.OracleRegistry
  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.LtiRedirect
  alias OliWeb.UserAuth
  alias OliWeb.Common.{Params, FormatDateTime}
  alias OliWeb.Delivery.InstructorDashboard.Helpers
  alias OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab
  alias OliWeb.Delivery.Student.Utils
  import OliWeb.ViewHelpers, only: [is_section_instructor_or_admin?: 2]
  alias Timex

  require Logger
  @learner_role_id ContextRoles.get_role(:context_learner).id
  @doc """
  This is the default entry point for delivery users. It will redirect to the appropriate page based
  on whether the user is an independent learner or an LTI user.

  If the user is an independent learner, they will be redirected to the student workspace.

  Otherwise, the user's LTI roles will be checked to determine if they are allowed to configure the
  section. If they are allowed to configure the section, they will be redirected to the instructor
  dashboard. If they are not allowed to configure the section, the student will be redirected to the
  page delivery.
  """
  @suspended_message "Your access to this course has been suspended. Please contact your instructor."

  def index(conn, _params) do
    case conn.assigns.current_user do
      %User{independent_learner: false} ->
        LtiRedirect.redirect_authenticated_user(conn, allow_new_section_creation: true)

      _ ->
        redirect(conn, to: ~p"/workspaces/student")
    end
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
         :ok <- Sections.ensure_enrollment_allowed(user, section),
         {:not_enrolled, nil} <- fetch_enrollment(section.slug, user.id) do
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
      {:enrolled, _} ->
        redirect(conn, to: ~p"/sections/#{section.slug}")

      {:suspended, _} ->
        conn
        |> put_flash(:error, @suspended_message)
        |> redirect(to: ~p"/users/log_in?request_path=%2Fsections%2F#{section.slug}")

      {:error, :independent_learner_not_allowed} ->
        conn
        |> put_flash(:error, "This course is only available through your LMS.")
        |> redirect(to: ~p"/workspaces/student")

      {:error, :non_independent_user} ->
        redirect_to_lms_instructions(conn, conn.assigns.section)

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
           :ok <- Sections.ensure_enrollment_allowed(user, section),
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
        {:error, :non_independent_user} ->
          redirect_to_lms_instructions(conn, conn.assigns.section)

        {:error, :independent_learner_not_allowed} ->
          conn
          |> put_flash(:error, "This course is only available through your LMS.")
          |> redirect(to: ~p"/workspaces/student")

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
    do: show_enroll(conn, Map.put(params, "from_invitation_link?", true))

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

  defp redirect_to_lms_instructions(conn, section) do
    request_path = build_request_path(conn)

    conn
    |> redirect(
      to: ~p"/lms_user_instructions?#{[section_title: section.title, request_path: request_path]}"
    )
  end

  defp build_request_path(%{request_path: nil}), do: nil

  defp build_request_path(conn) do
    case conn.query_string do
      nil -> conn.request_path
      "" -> conn.request_path
      query -> conn.request_path <> "?" <> query
    end
  end

  defp render_section_unavailable(conn, reason) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> put_status(403)
    |> render("section_unavailable.html", reason: reason)
    |> halt()
  end

  defp fetch_enrollment(section_slug, user_id) do
    case Sections.get_enrollment(section_slug, user_id, filter_by_status: false) do
      %_{status: :enrolled} = enrollment -> {:enrolled, enrollment}
      %_{status: :suspended} = enrollment -> {:suspended, enrollment}
      _ -> {:not_enrolled, nil}
    end
  end

  def download_course_content_info(conn, params) do
    with {:ok, section} <- ensure_instructor_access(conn) do
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
      |> put_resp_header("content-type", "text/csv")
      |> send_download({:binary, contents},
        filename: "#{section.slug}_course_content.csv"
      )
    else
      {:error, :forbidden} -> render_forbidden(conn)
      {:error, :not_found} -> render_section_not_found(conn)
    end
  end

  def download_intelligent_dashboard(conn, params) do
    with {:ok, section} <- ensure_instructor_access(conn),
         {:ok, current_user_id} <- current_user_id(conn),
         {:ok, scope_selector} <- dashboard_scope_selector(section, params),
         scope <- IntelligentDashboardTab.parse_scope(scope_selector),
         {:ok, context} <- dashboard_context(section.id, current_user_id, scope),
         {:ok, dependency_profile} <- dashboard_dependency_profile(),
         {:ok, bundle} <-
           build_dashboard_export_bundle(
             context,
             dependency_profile,
             dashboard_timezone(params)
           ),
         {:ok, zip_binary, _manifest} <-
           CsvExport.build_zip(bundle, dashboard_export_request(section, scope_selector, params)) do
      conn
      |> put_resp_header("content-type", "application/zip")
      |> send_download({:binary, zip_binary},
        filename: dashboard_export_filename(section.slug)
      )
    else
      {:error, :forbidden} -> render_forbidden(conn)
      {:error, :not_found} -> render_section_not_found(conn)
      {:error, :invalid_scope} -> render_forbidden(conn)
      {:error, :missing_user_id} -> render_forbidden(conn)
      {:error, _reason} -> render_forbidden(conn)
    end
  end

  def download_students_progress(conn, _params) do
    with {:ok, section} <- ensure_instructor_access(conn) do
      students = Helpers.get_students(section, :context_learner)

      base_headers = [
        name: "Name",
        email: "Email",
        lms_id: "LMS ID",
        last_interaction: "Last Interaction",
        progress: "Progress (Pct)",
        overall_proficiency: "Proficiency",
        requires_payment: "Requires Payment",
        status: "Status"
      ]

      headers =
        if section.certificate_enabled,
          do: base_headers ++ [certificate_status: "Certificate Status"],
          else: base_headers

      contents =
        Enum.map(
          students,
          fn student ->
            base_map = %{
              name: OliWeb.Common.Utils.name(student),
              email: student.email,
              lms_id: student.sub,
              last_interaction: student.last_interaction,
              progress: convert_to_percentage(student),
              overall_proficiency: student.overall_proficiency,
              requires_payment: Map.get(student, :requires_payment, "N/A"),
              status: Utils.parse_enrollment_status(student.enrollment_status)
            }

            if section.certificate_enabled,
              do:
                Map.put(
                  base_map,
                  :certificate_status,
                  Utils.parse_certificate_status(
                    case Map.get(student, :certificate) do
                      nil -> nil
                      cert -> cert.state
                    end
                  )
                ),
              else: base_map
          end
        )
        |> sort_data()
        |> DataTable.new()
        |> DataTable.headers(headers)
        |> DataTable.to_csv_content()

      conn
      |> put_resp_header("content-type", "text/csv")
      |> send_download({:binary, contents},
        filename: "#{section.slug}_students.csv"
      )
    else
      {:error, :forbidden} -> render_forbidden(conn)
      {:error, :not_found} -> render_section_not_found(conn)
    end
  end

  def download_learning_objectives(conn, _params) do
    with {:ok, section} <- ensure_instructor_access(conn) do
      contents =
        Sections.get_objectives_and_subobjectives(section, exclude_sub_objectives: false)
        |> Enum.map(fn objective ->
          %{
            subobjective: subobjective,
            student_proficiency_subobj: student_proficiency_subobj,
            student_proficiency_obj: student_proficiency_obj
          } =
            objective

          %{
            objective: (!subobjective && objective.title) || nil,
            subobjective: subobjective,
            student_proficiency_obj:
              (!student_proficiency_subobj && student_proficiency_obj) || nil,
            student_proficiency_subobj: student_proficiency_subobj
          }
        end)
        |> DataTable.new()
        |> DataTable.headers([
          :objective,
          :subobjective,
          :student_proficiency_obj,
          :student_proficiency_subobj
        ])
        |> DataTable.to_csv_content()

      conn
      |> put_resp_header("content-type", "text/csv")
      |> send_download({:binary, contents},
        filename: "#{section.slug}_learning_objectives.csv"
      )
    else
      {:error, :forbidden} -> render_forbidden(conn)
      {:error, :not_found} -> render_section_not_found(conn)
    end
  end

  def download_scored_pages(conn, _params) do
    with {:ok, section} <- ensure_instructor_access(conn) do
      students = instructor_dashboard_students(section.slug)

      pages =
        Helpers.get_assessments(section, students)
        |> Helpers.load_metrics(section, students)

      conn
      |> send_pages_csv(section, pages, :scored)
    else
      {:error, :forbidden} -> render_forbidden(conn)
      {:error, :not_found} -> render_section_not_found(conn)
    end
  end

  def download_practice_pages(conn, _params) do
    with {:ok, section} <- ensure_instructor_access(conn) do
      students = instructor_dashboard_students(section.slug)

      pages =
        Helpers.get_practice_pages(section, students)
        |> Helpers.load_metrics(section, students)

      conn
      |> send_pages_csv(section, pages, :practice)
    else
      {:error, :forbidden} -> render_forbidden(conn)
      {:error, :not_found} -> render_section_not_found(conn)
    end
  end

  def download_quiz_scores(conn, _params) do
    with {:ok, section} <- ensure_instructor_access(conn) do
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
        filename: "#{section.slug}_quiz_scores.csv"
      )
    else
      {:error, :forbidden} -> render_forbidden(conn)
      {:error, :not_found} -> render_section_not_found(conn)
    end
  end

  @doc """
  Endpoint that triggers download of a container specific progress report.
  """
  def download_container_progress(conn, %{"container_id" => container_id, "title" => title}) do
    {container_id, _} = Integer.parse(container_id)

    with {:ok, section} <- ensure_instructor_access(conn) do
      students =
        Helpers.get_students(section, %{container_id: container_id}, :context_learner)

      contents =
        Enum.map(
          students,
          &%{
            status: Utils.parse_enrollment_status(&1.enrollment_status),
            name: OliWeb.Common.Utils.name(&1),
            email: &1.email,
            lms_id: &1.sub,
            last_interaction: &1.last_interaction,
            progress: convert_to_percentage(&1),
            overall_proficiency: &1.overall_proficiency
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
          overall_proficiency: "Proficiency"
        )
        |> DataTable.to_csv_content()

      send_download(conn, {:binary, contents},
        filename: "progress__#{section.slug}__#{generate_title(title)}.csv"
      )
    else
      {:error, :forbidden} -> render_forbidden(conn)
      {:error, :not_found} -> render_section_not_found(conn)
    end
  end

  defp send_pages_csv(conn, section, pages, type) do
    include_due_date = type == :scored

    contents =
      pages
      |> build_pages_csv_rows(section, include_due_date: include_due_date)
      |> DataTable.new()
      |> DataTable.headers(pages_headers(include_due_date))
      |> DataTable.to_csv_content()

    filename =
      case type do
        :scored -> "#{section.slug}_scored_pages.csv"
        :practice -> "#{section.slug}_practice_pages.csv"
      end

    conn
    |> send_download({:binary, contents}, filename: filename)
  end

  defp pages_headers(include_due_date) do
    base_headers = [
      order: "#",
      page_title: "Page Title",
      avg_score: "Avg Score",
      total_attempts: "Total Attempts",
      student_progress: "Student Progress"
    ]

    if include_due_date,
      do: List.insert_at(base_headers, 2, {:due_date, "Due Date"}),
      else: base_headers
  end

  defp build_pages_csv_rows(pages, section, opts) do
    include_due_date = Keyword.get(opts, :include_due_date, false)

    Enum.map(pages, fn page ->
      base_row = %{
        order: page.order,
        page_title: format_page_title_for_csv(page),
        avg_score: format_percentage_value(page.avg_score),
        total_attempts: format_total_attempts(page.total_attempts),
        student_progress: format_percentage_value(page.students_completion)
      }

      if include_due_date,
        do: Map.put(base_row, :due_date, format_due_date_for_csv(page, section)),
        else: base_row
    end)
  end

  defp format_page_title_for_csv(%{container_label: nil, title: title}), do: title

  defp format_page_title_for_csv(%{container_label: container, title: title})
       when container in [nil, ""] do
    title
  end

  defp format_page_title_for_csv(%{container_label: container, title: title}),
    do: "#{container} - #{title}"

  defp format_percentage_value(nil), do: "-"

  defp format_percentage_value(value) when is_float(value) or is_integer(value) do
    value =
      if value <= 1, do: value * 100, else: value

    "#{Utils.parse_score(value)}%"
  end

  defp format_total_attempts(nil), do: "-"
  defp format_total_attempts(value), do: value

  defp format_due_date_for_csv(%{scheduling_type: :due_by, end_date: nil}, _section),
    do: "No due date"

  defp format_due_date_for_csv(%{scheduling_type: :due_by, end_date: datetime}, section) do
    timezone = section.timezone || FormatDateTime.default_timezone()

    datetime
    |> FormatDateTime.convert_datetime(timezone)
    |> case do
      nil -> "No due date"
      shifted -> Timex.format!(shifted, "{Mshort}. {0D}, {YYYY} - {h12}:{m} {AM}")
    end
  end

  defp format_due_date_for_csv(_, _), do: "No due date"

  defp instructor_dashboard_students(section_slug) do
    Sections.enrolled_students(section_slug)
    |> Enum.reject(&(&1.user_role_id != @learner_role_id))
  end

  def generate_title(title) when is_binary(title) do
    title
    |> remove_special_chars()
    |> String.slice(0, 50)
  end

  defp remove_special_chars(string) do
    string
    # Remove all non-alphanumeric except space
    |> String.replace(~r/[^A-Za-z0-9\s]/u, "")
    # Replace spaces with underscores
    |> String.replace(~r/\s+/, "_")
    # Remove leading/trailing underscores
    |> String.trim("_")
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
    Enum.sort_by(
      results,
      &{&1.status, String.downcase(&1.name), String.downcase("#{&1.email}"), &1.lms_id}
    )
  end

  defp convert_to_percentage(%{progress: nil}), do: 0

  defp convert_to_percentage(%{progress: progress}) when progress <= 1.0 do
    Utils.parse_score(progress * 100)
  end

  defp convert_to_percentage(%{progress: _progress} = user_data) do
    Logger.error("Progress exceeds 1.0 threshold: #{inspect(user_data)}")
    nil
  end

  defp build_dashboard_export_bundle(context, dependency_profile, timezone) do
    request_token = Integer.to_string(System.unique_integer([:positive]))

    with {:ok, oracle_results} <-
           build_dashboard_runtime_results(request_token, context, dependency_profile),
         {:ok, snapshot} <-
           Assembler.assemble(context, request_token, oracle_results,
             scope: context.scope,
             expected_oracles: dependency_profile.required ++ dependency_profile.optional,
             metadata: %{timezone: timezone, source: :instructor_insights}
           ),
         {:ok, %{projections: projection_map, statuses: projection_statuses}} <-
           Projections.derive_all(snapshot, projection_opts()) do
      {:ok,
       %{
         snapshot: %{
           snapshot
           | projections: projection_map,
             projection_statuses: projection_statuses
         },
         projections: projection_map,
         projection_statuses: projection_statuses,
         context: context,
         scope: context.scope,
         request_token: request_token,
         dependency_profile: dependency_profile
       }}
    end
  end

  defp build_dashboard_runtime_results(request_token, context, dependency_profile) do
    oracle_keys = Enum.uniq(dependency_profile.required ++ dependency_profile.optional)

    results =
      Enum.reduce(oracle_keys, %{}, fn oracle_key, acc ->
        Map.put(acc, oracle_key, dashboard_runtime_result(request_token, oracle_key, context))
      end)

    {:ok, results}
  end

  defp dashboard_runtime_result(_request_token, oracle_key, context) do
    case OracleRegistry.oracle_module(oracle_key) do
      {:ok, module} ->
        load_oracle_result(module, oracle_key, context)

      {:error, reason} ->
        Result.error(oracle_key, reason)
    end
  end

  defp load_oracle_result(module, oracle_key, context) do
    case OracleContext.new(context) do
      {:ok, oracle_context} ->
        case module.load(oracle_context, []) do
          {:ok, payload} ->
            Result.ok(oracle_key, payload,
              version: oracle_version(module),
              metadata: %{source: :runtime, dashboard_product: :instructor_dashboard}
            )

          {:error, reason} ->
            Result.error(oracle_key, reason,
              version: oracle_version(module),
              metadata: %{source: :runtime, dashboard_product: :instructor_dashboard}
            )
        end

      {:error, reason} ->
        Result.error(oracle_key, {:invalid_oracle_context, reason},
          version: oracle_version(module),
          metadata: %{source: :runtime, dashboard_product: :instructor_dashboard}
        )
    end
  end

  defp oracle_version(module) do
    if function_exported?(module, :version, 0), do: module.version(), else: 1
  end

  defp projection_opts do
    [
      inactivity_days: 7,
      completion_threshold_pct: 50
    ]
  end

  defp dashboard_context(section_id, user_id, scope) do
    {:ok,
     %{
       dashboard_context_type: :section,
       dashboard_context_id: section_id,
       user_id: user_id,
       scope: scope
     }}
  end

  defp dashboard_dependency_profile do
    consumers = [
      :progress_summary,
      :support_summary,
      :challenging_objectives,
      :assessments_summary
    ]

    Enum.reduce_while(consumers, {:ok, %{required: [], optional: []}}, fn consumer, {:ok, acc} ->
      case OracleRegistry.dependencies_for(consumer) do
        {:ok, %{required: required, optional: optional}} ->
          {:cont,
           {:ok,
            %{
              required: Enum.uniq(acc.required ++ required),
              optional: Enum.uniq(acc.optional ++ optional)
            }}}

        {:error, reason} ->
          {:halt, {:error, {:dependency_profile_unavailable, consumer, reason}}}

        other ->
          {:halt, {:error, {:dependency_profile_unavailable, consumer, other}}}
      end
    end)
  end

  defp current_user_id(conn) do
    case conn.assigns[:current_user] do
      %{id: user_id} when is_integer(user_id) -> {:ok, user_id}
      _ -> {:error, :missing_user_id}
    end
  end

  defp dashboard_scope_selector(section, params) do
    scope_selector = Map.get(params, "dashboard_scope", "course")

    case IntelligentDashboardTab.validate_scope_selector(section, scope_selector) do
      {:ok, normalized_scope_selector} -> {:ok, normalized_scope_selector}
      :error -> {:error, :invalid_scope}
    end
  end

  defp dashboard_export_request(section, scope_selector, params) do
    progress_tile_state = IntelligentDashboardTab.parse_progress_tile_state(params)
    course_name = section_course_title(section)

    %{
      export_profile: :instructor_dashboard,
      include_manifest: false,
      generated_at: DateTime.utc_now(),
      course_name: course_name,
      course_section: section.title,
      dashboard_scope: scope_selector,
      dashboard_scope_label: dashboard_scope_label(scope_selector),
      timezone: dashboard_timezone(params),
      progress_completion_threshold: progress_tile_state.completion_threshold,
      proficiency_definition: "Learning objective proficiency based on first-attempt correctness"
    }
  end

  defp section_course_title(%Sections.Section{base_project_id: project_id})
       when is_integer(project_id) do
    Course.get_project!(project_id).title
  end

  defp dashboard_scope_label("course"), do: "Entire Course"
  defp dashboard_scope_label("container:" <> _id), do: "Selected Scope"
  defp dashboard_scope_label(_), do: "Selected Scope"

  defp dashboard_timezone(params) do
    case Map.get(params, "timezone") do
      timezone when is_binary(timezone) and timezone != "" -> timezone
      _ -> "Etc/UTC"
    end
  end

  defp dashboard_export_filename(section_slug) do
    timestamp =
      DateTime.utc_now()
      |> Calendar.strftime("%Y%m%d_%H%M%S")

    "#{section_slug}_intelligent_dashboard_export_#{timestamp}.zip"
  end

  defp ensure_instructor_access(conn) do
    case conn.assigns[:section] do
      %Sections.Section{} = section ->
        if authorized_instructor?(conn, section) do
          {:ok, section}
        else
          {:error, :forbidden}
        end

      _ ->
        {:error, :not_found}
    end
  end

  defp authorized_instructor?(conn, section) do
    conn.assigns[:is_instructor] ||
      is_section_instructor_or_admin?(section.slug, conn.assigns[:current_user]) ||
      is_section_instructor_or_admin?(section.slug, conn.assigns[:current_author])
  end

  defp render_forbidden(conn) do
    conn
    |> put_view(OliWeb.PageDeliveryView)
    |> put_status(:forbidden)
    |> render("not_authorized.html")
    |> halt()
  end

  defp render_section_not_found(conn) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> put_status(:not_found)
    |> render("section_not_found.html")
    |> halt()
  end

  @doc """
  Redirects to the instructor dashboard insights view by default.
  This is the entry point for the instructor dashboard route.
  """
  def instructor_dashboard(conn, %{"section_slug" => section_slug}) do
    redirect(conn, to: ~p"/sections/#{section_slug}/instructor_dashboard/insights/dashboard")
  end
end
