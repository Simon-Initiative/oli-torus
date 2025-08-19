defmodule OliWeb.Grades.GradesLive do
  use OliWeb, :live_view

  alias Oli.Grading
  alias Lti_1p3.Tool.Services.AGS
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.PageLifecycle.Broadcaster
  alias Oli.Lti.AccessTokenLibrary
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Grades.{Export, GradeSync, LineItems, TestConnection}
  alias Oli.Delivery.Sections.LineItemsCreator

  def set_breadcrumbs(type, section) do
    type
    |> OliWeb.Sections.OverviewView.set_breadcrumbs(section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Manage LMS Gradebook",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, _session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        {_d, registration} = Sections.get_deployment_registration_from_section(section)
        line_items_url = section.line_items_service_url
        graded_pages = Sections.fetch_scored_pages(section.slug)

        selected_page =
          if length(graded_pages) > 0 do
            hd(graded_pages).resource_id
          else
            nil
          end

        # Subscribe to line items creator updates
        Phoenix.PubSub.subscribe(Oli.PubSub, "line_items_creator:#{section.slug}")

        {:ok,
         assign(socket,
           title: "LMS Grades",
           breadcrumbs: set_breadcrumbs(type, section),
           graded_pages: graded_pages,
           selected_page: selected_page,
           line_items_url: line_items_url,
           access_token: nil,
           task_queue: [],
           progress_current: 0,
           progress_max: 0,
           section_slug: section.slug,
           section: section,
           registration: registration,
           total_jobs: nil,
           failed_jobs: nil,
           succeeded_jobs: nil,
           test_output: nil,
           test_in_progress?: false,
           line_items_job_id: nil,
           line_items_job_status: nil
         )}
    end
  end

  def render(assigns) do
    has_tasks? = length(assigns.task_queue) > 0

    assigns =
      assigns
      |> assign(
        :progress_visible,
        if has_tasks? do
          "visible"
        else
          "invisible"
        end
      )
      |> assign(
        :percent_progress,
        case assigns.progress_max do
          0 -> 0
          v -> assigns.progress_current / v * 100
        end
      )

    ~H"""
    <div class="container mx-auto">
      <h2>{dgettext("grades", "Manage Grades")}</h2>

      <p>
        {dgettext(
          "grades",
          "Grades for this section can be viewed by students and instructors using the LMS gradebook."
        )}
      </p>

      <div class="my-2">
        <TestConnection.render section={@section} test_output={@test_output} />
      </div>
      <div class="my-2">
        <Export.render section_slug={@section_slug} />
      </div>

      <div class="my-2">
        <LineItems.render
          task_queue={@task_queue}
          job_status={@line_items_job_status}
          section_slug={@section_slug}
        />
      </div>
      <div class="my-2">
        <GradeSync.render
          total_jobs={@total_jobs}
          failed_jobs={@failed_jobs}
          succeeded_jobs={@succeeded_jobs}
          graded_pages={@graded_pages}
          selected_page={@selected_page}
        />
      </div>

      <div class={"my-2 #{@progress_visible}"}>
        <p>{dgettext("grades", "Do not leave this page until this operation completes.")}</p>
        <div class="progress">
          <div
            class="progress-bar"
            role="progressbar"
            style={"width: #{@percent_progress}%;"}
            aria-valuenow={"#{@percent_progress}"}
            aria-valuemin="0"
            aria-valuemax="100"
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp host() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end

  defp access_token_provider(registration) do
    provider =
      :oli
      |> Application.get_env(:lti_access_token_provider)
      |> Keyword.get(:provider, AccessTokenLibrary)

    provider.fetch_access_token(registration, Grading.ags_scopes(), host())
  end

  defp fetch_students(section, _access_token \\ nil) do
    # Query the db to find all enrolled students
    students = Sections.fetch_students(section.slug)

    # ## MER-3566 - Disable NRPS course membership filtering for now
    # # If NRPS is enabled, request the latest view of the course membership
    # # and filter our enrolled students to that list.  This step avoids us
    # # ever sending grade posts for students that have dropped the class.
    # # Those requests would simply fail, but this extra step eliminates making
    # # those requests altogether.
    # if section.nrps_enabled do
    #   case NRPS.fetch_memberships(section.nrps_context_memberships_url, access_token) do
    #     {:ok, memberships} ->
    #       # get a set of the subs corresponding to Active students
    #       subs =
    #         Enum.filter(memberships, fn m -> m.status == "Active" end)
    #         |> Enum.map(fn m -> m.user_id end)
    #         |> MapSet.new()

    #       Enum.filter(students, fn s -> MapSet.member?(subs, s.sub) end)

    #     _ ->
    #       students
    #   end
    # else
    #   students
    # end

    students
  end

  def emit_status(pid, status, decoration, is_done?) do
    send(pid, {:test_status, status, decoration, is_done?})
  end

  def handle_event("send_line_items", _, socket) do
    section = socket.assigns.section

    # Start the async line items creation process
    case LineItemsCreator.create_all_line_items(section.slug) do
      {:ok, job_id} ->
        {:noreply,
         socket
         |> assign(:line_items_job_id, job_id)
         |> put_flash(
           :info,
           dgettext(
             "grades",
             "Line items creation started. You can close this page and the process will continue in the background."
           )
         )}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Failed to start line items creation: #{inspect(reason)}")}
    end
  end

  def handle_event("select_page", %{"resource_id" => resource_id}, socket) do
    {resource_id, _} = Integer.parse(resource_id)

    {:noreply,
     assign(socket,
       selected_page: resource_id,
       total_jobs: nil,
       failed_jobs: nil,
       succeeded_jobs: nil
     )}
  end

  def handle_event("test_connection", _, socket) do
    registration = socket.assigns.registration
    pid = self()

    emit_status(pid, "Starting test", :normal, false)

    Task.async(fn ->
      emit_status(pid, "Requesting access token...", :normal, false)

      try do
        case access_token_provider(registration) do
          {:ok, access_token} ->
            emit_status(pid, "Received access token", :normal, false)
            emit_status(pid, "Requesting line items...", :normal, false)

            case AGS.fetch_line_items(socket.assigns.line_items_url, access_token) do
              {:ok, _} ->
                emit_status(pid, "Received line items", :normal, false)
                emit_status(pid, "Success!", :success, true)

              {:error, e} ->
                emit_status(pid, e, :failure, true)
            end

          {:error, e} ->
            emit_status(pid, e, :failure, true)
        end
      rescue
        e in RuntimeError -> emit_status(pid, "Failed! " <> e.message, :failure, true)
        _ -> emit_status(pid, "Failed! Unknown failure", :failure, true)
      end
    end)

    {:noreply, assign(socket, test_in_progress?: true, test_output: [])}
  end

  def handle_event("send_grades", _, socket) do
    section = socket.assigns.section

    page =
      Enum.find(socket.assigns.graded_pages, fn p ->
        p.resource_id == socket.assigns.selected_page
      end)

    # Obtain a MapSet of enrolled student ids in this course section
    user_ids =
      fetch_students(section)
      |> Enum.map(fn u -> u.id end)
      |> MapSet.new()

    # Spawn grade update workers for every student that has a finalized
    # resource access in this section
    total_jobs =
      Attempts.get_resource_access_for_page(section.slug, page.resource_id)
      |> Enum.filter(fn ra -> MapSet.member?(user_ids, ra.user_id) end)
      |> Enum.filter(fn ra -> !is_nil(ra.score) end)
      |> Enum.filter(fn ra ->
        case Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker.create(
               section.id,
               ra.id,
               :manual_batch
             ) do
          {:ok, job} ->
            Broadcaster.subscribe_to_lms_grade_update(
              socket.assigns.section.id,
              ra.id,
              job.id
            )

            true

          _ ->
            false
        end
      end)
      |> Enum.count()

    {:noreply, assign(socket, total_jobs: total_jobs, failed_jobs: 0, succeeded_jobs: 0)}
  end

  def handle_info({:test_status, status, decoration, is_done}, socket) do
    test_output =
      if is_nil(socket.assigns.test_output) do
        []
      else
        socket.assigns.test_output
      end ++
        [{status, decoration}]

    {:noreply, assign(socket, test_output: test_output, test_in_progress?: !is_done)}
  end

  def handle_info({:lms_grade_update_result, payload}, socket) do
    %Oli.Delivery.Attempts.PageLifecycle.GradeUpdatePayload{
      resource_access_id: resource_access_id,
      job: %{id: job_id},
      status: result
    } = payload

    # Unsubscribe to this job when we reach a terminal state
    if result in [:success, :failure, :not_synced] do
      Broadcaster.unsubscribe_to_lms_grade_update(
        socket.assigns.section.id,
        resource_access_id,
        job_id
      )
    end

    failed_jobs =
      if result == :failure do
        socket.assigns.failed_jobs + 1
      else
        socket.assigns.failed_jobs
      end

    succeeded_jobs =
      if result == :success or result == :not_synced do
        socket.assigns.succeeded_jobs + 1
      else
        socket.assigns.succeeded_jobs
      end

    {:noreply,
     assign(socket,
       failed_jobs: failed_jobs,
       succeeded_jobs: succeeded_jobs
     )}
  end

  def handle_info({:line_items_status, status}, socket) do
    {:noreply, assign(socket, :line_items_job_status, status)}
  end

  def handle_info(_, socket) do
    # needed to ignore results of Task invocation
    {:noreply, socket}
  end
end
