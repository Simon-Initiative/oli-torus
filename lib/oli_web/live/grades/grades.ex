defmodule OliWeb.Grades.GradesLive do

  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use Phoenix.HTML

  alias Oli.Grading
  alias Oli.Grading.LTI_AGS
  alias Oli.Grading.LineItem
  alias Oli.Lti_1p3.AccessToken
  alias Oli.Lti_1p3.ContextRoles
  alias Oli.Delivery.Attempts.ResourceAccess

  def mount(%{"context_id" => context_id}, %{"lti_params" => lti_params, "current_user" => current_user}, socket) do

    if ContextRoles.has_role?(current_user, context_id, ContextRoles.get_role(:context_instructor)) do

      line_items_url = LTI_AGS.get_line_items_url(lti_params)

      {:ok, assign(socket,
        cached_line_items: %{},
        line_items_url: line_items_url,
        access_token: nil,
        task_queue: [],
        progress_current: 0,
        progress_max: 0,
        context_id: context_id,
        lti_params: lti_params)
      }
    else
      {:ok, redirect(socket, to: "/unauthorized")}
    end
  end

  def render(assigns) do

    iss = assigns.lti_params["iss"]
    has_tasks? = length(assigns.task_queue) > 0
    progress_visible = if has_tasks? do "visible" else "invisible" end

    percent_progress = case assigns.progress_max do
      0 -> 0
      v -> (assigns.progress_current / v) * 100
    end

    ~L"""
    <h2>Manage Grades</h2>

    <p>Grades for OLI graded pages for this course are accessed by students and instructors from the LMS gradebook at <a href="<%= iss %>"><%= iss %></a>.</p>

    <div class="card-group">

      <%= live_component @socket, OliWeb.Grades.LineItems, assigns %>
      <%= live_component @socket, OliWeb.Grades.GradeSync, assigns %>
      <%= live_component @socket, OliWeb.Grades.Export, assigns %>

    </div>

    <div class="mt-4 <%= progress_visible %>">
      <p>Do not leave this page until this operation completes.</p>
      <div class="progress">
        <div class="progress-bar" role="progressbar" style="width: <%= percent_progress %>%;" aria-valuenow="<%= percent_progress %>" aria-valuemin="0" aria-valuemax="100">
      </div>
    </div>

    """
  end

  defp determine_line_item_tasks(graded_pages, line_items) do

    line_item_map = Enum.reduce(line_items, %{}, fn i, m -> Map.put(m, i.resourceId, i) end)

    # tasks to create line items for graded pages that do not have them
    creation_tasks = Enum.filter(graded_pages, fn p -> !Map.has_key?(line_item_map, LineItem.to_resource_id(p.resource_id)) end)
    |> Enum.map(fn p ->
      fn assigns ->
        LTI_AGS.create_line_item(assigns.line_items_url, p.resource_id, 1, p.title, assigns.access_token)
      end
    end)

    # tasks to update the labels of line items whose corresponding graded page's title has changed
    update_tasks = Enum.filter(graded_pages, fn p -> Map.has_key?(line_item_map, LineItem.to_resource_id(p.resource_id)) and Map.get(line_item_map, LineItem.to_resource_id(p.resource_id)).label != p.title end)
    |> Enum.map(fn p ->
      fn assigns ->
        line_item = Map.get(line_item_map, LineItem.to_resource_id(p.resource_id))
        LTI_AGS.update_line_item(line_item, %{label: p.title}, assigns.access_token)
      end
    end)

    creation_tasks ++ update_tasks
  end

  defp determine_grade_sync_tasks(context_id, graded_pages) do

    # get students enrolled in the section, filter by role: student
    students = Grading.fetch_students(context_id)

    # create a map of all resource accesses, keyed off resource id
    resource_accesses = Grading.fetch_resource_accesses(context_id)

    # create a task to post a score for each student's resource_access record
    Enum.reduce(students, [], fn %{id: user_id, sub: sub}, tasks ->

      Enum.reduce(graded_pages, tasks, fn revision, acc ->

        case resource_accesses[revision.resource_id] do
          %{^user_id => student_resource_accesses} ->
            case student_resource_accesses do
              %ResourceAccess{score: score, out_of: out_of} ->

                # Here we preprend a function that when invoked will
                # post the score to the AGS endpoint
                if (score != nil and out_of != nil) do

                  [fn assigns ->
                    line_item = Map.get(assigns.cached_line_items, LineItem.to_resource_id(revision.resource_id))

                    Grading.to_score(sub, student_resource_accesses)
                    |> LTI_AGS.post_score(line_item, assigns.access_token)

                  end | acc]

                else
                  acc
                end

              _ -> acc
            end
          _ -> acc
        end

      end)
    end)

  end

  defp host() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end

  defp access_token_provider(lti_launch_params) do
    deployment_id = Oli.Lti_1p3.get_deployment_id_from_launch(lti_launch_params)
    AccessToken.fetch_access_token(deployment_id, Grading.ags_scopes(), host())
  end

  def handle_event("send_line_items", _, socket) do

    case fetch_line_items(socket.assigns.lti_params, socket.assigns.line_items_url) do

      {:ok, line_items, access_token} ->

        graded_pages = Grading.fetch_graded_pages(socket.assigns.context_id)

        case determine_line_item_tasks(graded_pages, line_items) do

          [] -> {:noreply, put_flash(socket, :info, "LMS line items already up to date")}

          task_queue ->

            # Kick off the serial processing of the queue by popping the first item
            send(self(), :pop_task_queue)

            {:noreply, assign(socket, access_token: access_token,
              task_queue: task_queue, progress_max: length(task_queue), progress_current: 0)}

        end

      {:error, e} -> {:noreply, put_flash(socket, :error, e)}

    end

  end

  def handle_event("send_grades", _, socket) do

    case fetch_line_items(socket.assigns.lti_params, socket.assigns.line_items_url) do

      {:ok, line_items, access_token} ->

        # cache all existing line items, we will need these to be able to
        # support a full grade sync
        cached_line_items = Enum.reduce(line_items, %{}, fn i, m -> Map.put(m, i.resourceId, i) end)

        # determine the line item and score posting tasks
        graded_pages = Grading.fetch_graded_pages(socket.assigns.context_id)
        line_item_tasks = determine_line_item_tasks(graded_pages, line_items)
        score_tasks = determine_grade_sync_tasks(socket.assigns.context_id, graded_pages)

        # assemble the full queue of tasks and pop the first one to kick off
        # the serial processing of these
        task_queue = line_item_tasks ++ score_tasks
        send(self(), :pop_task_queue)

        {:noreply, assign(socket,
          cached_line_items: cached_line_items,
          access_token: access_token,
          task_queue: task_queue,
          progress_max: length(task_queue), progress_current: 0)}

      {:error, e} -> {:noreply, put_flash(socket, :error, e)}

    end

  end

  defp fetch_line_items(lti_params, line_items_url) do

    case access_token_provider(lti_params) do

      {:ok, access_token} ->

        case LTI_AGS.fetch_line_items(line_items_url, access_token) do

          {:ok, line_items} -> {:ok, line_items, access_token}
          _ -> {:error, "Error accessing LMS line items"}
        end

      _ -> {:error, "Error getting LMS access token"}

    end

  end

  def handle_info(:pop_task_queue, socket) do

    # take the first item off the queue
    [task | task_queue] = socket.assigns.task_queue

    # and invoke the task, providing the current socket assigns
    # as context
    case task.(socket.assigns) do
      {:ok, result} ->

        # When we process a line item creation or update, we cache the result
        # because a full grade sync will need these line items to issue the score post
        cached_line_items = case result do
          %LineItem{} = line_item -> Map.put(socket.assigns.cached_line_items, line_item.resourceId, line_item)
          _ -> socket.assigns.cached_line_items
        end

        # See if there is another item in the queue to pop
        socket = if length(task_queue) > 0 do
          send(self(), :pop_task_queue)
          socket
        else
          socket |> put_flash(:info, "LMS up to date")
        end

        {:noreply, assign(socket, cached_line_items: cached_line_items,
          task_queue: task_queue, progress_current: socket.assigns.progress_current + 1)}

      {:error, e} ->
        socket = socket |> put_flash(:error, e)
        {:noreply, assign(socket, task_queue: [])}
    end

  end

end
