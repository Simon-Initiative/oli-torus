defmodule OliWeb.Grades.GradesLive do
  use OliWeb, :live_view

  alias Oli.Grading
  alias Lti_1p3.Tool.Services.AGS
  alias Lti_1p3.Tool.Services.AGS.LineItem
  alias Lti_1p3.Tool.Services.NRPS
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Sections
  alias Oli.Accounts
  alias Oli.Repo
  alias Oli.Delivery.Attempts.PageLifecycle.Broadcaster
  alias Oli.Lti.AccessTokenLibrary

  def mount(
        _params,
        %{"section_slug" => section_slug} = session,
        socket
      ) do
    section = Sections.get_section_by_slug(section_slug)

    if is_admin_author?(session) or is_instructor?(session, section) do
      do_mount(section, socket)
    else
      {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :unauthorized))}
    end
  end

  defp do_mount(section, socket) do
    {_d, registration} = Sections.get_deployment_registration_from_section(section)
    line_items_url = section.line_items_service_url
    graded_pages = Grading.fetch_graded_pages(section.slug)

    selected_page =
      if length(graded_pages) > 0 do
        hd(graded_pages).resource_id
      else
        nil
      end

    {:ok,
     assign(socket,
       title: "LMS Grades",
       breadcrumbs: [],
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
       test_in_progress?: false
     )}
  end

  defp is_admin_author?(session) do
    case session["current_author_id"] do
      nil ->
        false

      id ->
        case Repo.get(Oli.Accounts.Author, id) do
          nil -> false
          author -> Accounts.is_admin?(author)
        end
    end
  end

  defp is_instructor?(session, section) do
    case session["current_user_id"] do
      nil ->
        false

      id ->
        user = Accounts.get_user!(id) |> Repo.preload([:platform_roles, :author])

        ContextRoles.has_role?(
          user,
          section.slug,
          ContextRoles.get_role(:context_instructor)
        )
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
    <div class="mb-2">
      <%= link to: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, @section.slug) do %>
        <i class="fas fa-arrow-left"></i> Back
      <% end %>
    </div>

    <h2><%= dgettext("grades", "Manage Grades") %></h2>

    <p>
      <%= dgettext("grades", "Grades for this section can be viewed by students and instructors using the LMS gradebook.") %>
    </p>

    <div class="card-group">
      <%= live_component OliWeb.Grades.TestConnection, assigns %>
      <%= live_component OliWeb.Grades.Export, assigns %>
    </div>

    <div class="card-group">
      <%= live_component OliWeb.Grades.LineItems, assigns %>
      <%= live_component OliWeb.Grades.GradeSync, assigns %>
    </div>

    <div class={"mt-4 #{@progress_visible}"}>
      <p><%= dgettext("grades", "Do not leave this page until this operation completes.") %></p>
      <div class="progress">
        <div class="progress-bar" role="progressbar" style={"width: #{@percent_progress}%;"} aria-valuenow={"#{@percent_progress}"} aria-valuemin="0" aria-valuemax="100"></div>
      </div>
    </div>
    """
  end

  defp determine_line_item_tasks(graded_pages, line_items, section) do
    line_item_map = Enum.reduce(line_items, %{}, fn i, m -> Map.put(m, i.resourceId, i) end)

    # tasks to create line items for graded pages that do not have them
    creation_tasks =
      Enum.filter(graded_pages, fn p ->
        !Map.has_key?(line_item_map, LineItem.to_resource_id(p.resource_id))
      end)
      |> Enum.map(fn p ->
        fn assigns ->
          out_of = Oli.Grading.determine_page_out_of(section.slug, p)

          AGS.create_line_item(
            assigns.line_items_url,
            p.resource_id,
            out_of,
            p.title,
            assigns.access_token
          )
        end
      end)

    # tasks to update the labels of line items whose corresponding graded page's title has changed
    update_tasks =
      Enum.filter(graded_pages, fn p ->
        Map.has_key?(line_item_map, LineItem.to_resource_id(p.resource_id)) and
          Map.get(line_item_map, LineItem.to_resource_id(p.resource_id)).label != p.title
      end)
      |> Enum.map(fn p ->
        fn assigns ->
          line_item = Map.get(line_item_map, LineItem.to_resource_id(p.resource_id))
          AGS.update_line_item(line_item, %{label: p.title}, assigns.access_token)
        end
      end)

    creation_tasks ++ update_tasks
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

  defp fetch_students(access_token, section) do
    # Query the db to find all enrolled students
    students = Grading.fetch_students(section.slug)

    # If NRPS is enabled, request the latest view of the course membership
    # and filter our enrolled students to that list.  This step avoids us
    # ever sending grade posts for students that have dropped the class.
    # Those requests would simply fail, but this extra step eliminates making
    # those requests altogether.
    if section.nrps_enabled do
      case NRPS.fetch_memberships(section.nrps_context_memberships_url, access_token) do
        {:ok, memberships} ->
          # get a set of the subs corresponding to Active students
          subs =
            Enum.filter(memberships, fn m -> m.status == "Active" end)
            |> Enum.map(fn m -> m.user_id end)
            |> MapSet.new()

          Enum.filter(students, fn s -> MapSet.member?(subs, s.sub) end)

        _ ->
          students
      end
    else
      students
    end
  end

  def emit_status(pid, status, decoration, is_done?) do
    send(pid, {:test_status, status, decoration, is_done?})
  end

  def handle_event("send_line_items", _, socket) do
    registration = socket.assigns.registration

    case fetch_line_items(registration, socket.assigns.line_items_url) do
      {:ok, line_items, access_token} ->
        graded_pages = Grading.fetch_graded_pages(socket.assigns.section.slug)

        case determine_line_item_tasks(graded_pages, line_items, socket.assigns.section) do
          [] ->
            {:noreply,
             put_flash(socket, :info, dgettext("grades", "LMS line items already up to date"))}

          task_queue ->
            # Kick off the serial processing of the queue by popping the first item
            send(self(), :pop_task_queue)

            {:noreply,
             assign(socket,
               access_token: access_token,
               task_queue: task_queue,
               progress_max: length(task_queue),
               progress_current: 0
             )}
        end

      {:error, e} ->
        {:noreply, put_flash(socket, :error, e)}
    end
  end

  def handle_event("select_page", %{"page" => resource_id}, socket) do
    {:noreply, assign(socket, selected_page: resource_id)}
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
    registration = socket.assigns.registration

    page =
      Enum.find(socket.assigns.graded_pages, fn p ->
        p.resource_id == socket.assigns.selected_page
      end)

    case access_token_provider(registration) do
      {:ok, access_token} ->
        # Obtain a MapSet of enrolled student ids in this course section
        user_ids =
          fetch_students(access_token, section)
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

      {:error, e} ->
        {:noreply, put_flash(socket, :error, e)}
    end
  end

  defp fetch_line_items(registration, line_items_url) do
    case access_token_provider(registration) do
      {:ok, access_token} ->
        case AGS.fetch_line_items(line_items_url, access_token) do
          {:ok, line_items} -> {:ok, line_items, access_token}
          _ -> {:error, dgettext("grades", "Error accessing LMS line items")}
        end

      _ ->
        {:error, dgettext("grades", "Error getting LMS access token")}
    end
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

  def handle_info(:pop_task_queue, socket) do
    # take the first item off the queue
    [task | task_queue] = socket.assigns.task_queue

    # and invoke the task, providing the current socket assigns
    # as context. If any task fails we simply move on and execute the
    # next one.  Failed tasks would be encountered, for instance, if NRPS was not enabled and
    # score posts for students no longer enrolled are sent to the LMS.
    case task.(socket.assigns) do
      _ ->
        # See if there is another item in the queue to pop
        socket =
          if length(task_queue) > 0 do
            send(self(), :pop_task_queue)
            socket
          else
            socket |> put_flash(:info, dgettext("grades", "LMS up to date"))
          end

        {:noreply,
         assign(socket,
           task_queue: task_queue,
           progress_current: socket.assigns.progress_current + 1
         )}
    end
  end

  def handle_info(_, socket) do
    # needed to ignore results of Task invocation
    {:noreply, socket}
  end
end
