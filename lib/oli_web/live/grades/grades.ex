defmodule OliWeb.Grades.GradesLive do

  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use Phoenix.HTML

  alias Oli.Grading
  alias Oli.Grading.LTI_AGS
  alias Oli.Grading.LineItem
  alias Oli.Lti_1p3.AccessToken
  alias Oli.Lti_1p3.ContextRoles

  def mount(%{"context_id" => context_id}, %{"lti_params" => lti_params, "current_user" => current_user}, socket) do

    if ContextRoles.has_role?(current_user, context_id, ContextRoles.get_role(:context_instructor)) do

      line_items_url = LTI_AGS.get_line_items_url(lti_params)

      {:ok, assign(socket,
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

    <div class="mt-4">
      <p>Do not leave this page until this operation completes.</p>
      <div class="progress <%= progress_visible %>">
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
      fn line_items_url, access_token ->
        LTI_AGS.create_line_item(line_items_url, p.resource_id, 1, p.title, access_token)
      end
    end)

    # tasks to update the labels of line items whose corresponding graded page's title has changed
    update_tasks = Enum.filter(graded_pages, fn p -> Map.has_key?(line_item_map, LineItem.to_resource_id(p.resource_id)) and Map.get(line_item_map, Integer.to_string(p.resource_id)).label != p.title end)
    |> Enum.map(fn p ->
      fn _, access_token ->
        line_item = Map.get(line_item_map, LineItem.to_resource_id(p.resource_id))
        LTI_AGS.update_line_item(line_item, %{label: p.title}, access_token)
      end
    end)

    creation_tasks ++ update_tasks
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
            send(self(), :pop_task_queue)
            {:noreply, assign(socket, task_description: "Update LMS Line Items", access_token: access_token,
              task_queue: task_queue, progress_max: length(task_queue), progress_current: 0, cancelled: false)}

        end

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

    [task | task_queue] = socket.assigns.task_queue

    case task.(socket.assigns.line_items_url, socket.assigns.access_token) do
      {:ok, _} ->

        socket = if length(task_queue) > 0 do
          send(self(), :pop_task_queue)
          socket
        else
          socket |> put_flash(:info, "LMS line items up to date")
        end

        {:noreply, assign(socket, task_queue: task_queue, progress_current: socket.assigns.progress_current + 1)}

      {:error, e} ->
        socket = socket |> put_flash(:error, e)
        {:noreply, assign(socket, task_queue: [])}
    end

  end

end
