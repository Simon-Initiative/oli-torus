defmodule OliWeb.Workspaces.CourseAuthor.DatasetsLive do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.{Accounts}
  alias Oli.Analytics.Datasets.{BrowseJobOptions, DatasetJob}
  alias Oli.Analytics.Datasets
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{PagedTable, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel

  alias OliWeb.Workspaces.CourseAuthor.Datasets.{
    DatasetsTableModel
  }

  @limit 25

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    %{ctx: ctx} = socket.assigns

    project_id = case Map.get(params, "project_id") do
      nil -> nil
      project_slug -> Oli.Authoring.Course.get_project_by_slug(project_slug).id
    end

    options = %BrowseJobOptions{
      project_id: project_id,
      statuses: [],
      job_type: nil,
      initiated_by_id: nil
    }

    jobs =
      Datasets.browse_jobs(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :desc, field: :inserted_at},
        options
      )

    total_count = determine_total(jobs)

    users = Datasets.get_initator_values(project_id)

    projects = case project_id do
      nil -> Datasets.get_project_values()
      _ -> nil
    end

    {:ok, table_model} =
      DatasetsTableModel.new(jobs, project_id == nil)

    {:ok,
     assign(socket,
       active: :datasets,
       filter_type: :all,
       filter_user: :all,
       filter_project: :all,
       filter_status: :all,
       users: users,
       projects: projects,
       ctx: ctx,
       table_model: table_model,
       options: options,
       offset: 0,
       total_count: total_count,
       active_rows: jobs,
       query: "",
       limit: @limit
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    table_model = SortableTableModel.update_from_params(socket.assigns.table_model, params)

    offset = get_int_param(params, "offset", 0)

    options = socket.assigns.options

    jobs =
      Datasets.browse_jobs(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, jobs)
    total_count = determine_total(jobs)

    {:noreply,
     assign(socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h2 id="header_id" class="pb-2">Datasets</h2>
    <div class="mb-3">
      <p>
        View the status of dataset creation jobs and reqeust new dataset jobs.
      </p>
    </div>
    <div class="mt-5 mb-3">
      <p>Filter dataset jobs by:</p>
      <div class="d-flex justify-content-between">

        <form id="filter_form" />

        <%= if @projects do %>
          <select
            phx-change="filter_project"
            id="filter_project"
            name="filter_project"
            class="custom-select custom-select-lg mb-2"
            form="filter_form"
          >
            <option value={:all} selected={@filter_project == :all}>All Projects</option>
            <%= for project <- @projects do %>
              <option value={project.id} selected={@filter_project == project.id}>
                <%= project.title %>
              </option>
            <% end %>
          </select>
        <% end %>

        <select
          phx-change="filter_type"
          id="filter_type"
          name="filter_type"
          class="custom-select custom-select-lg mb-2"
          form="filter_form"
        >
          <option value={:all} selected={@filter_type == :all}>All Types</option>
          <option value={:datashop} selected={@filter_type == :datashop}>Datashop</option>
          <option value={:custom} selected={@filter_type == :custom}>Custom</option>
        </select>

        <select
          phx-change="filter_user"
          id="filter_user"
          name="filter_user"
          class="custom-select custom-select-lg mb-2"
          form="filter_user"
        >
          <option value={:all} selected={@filter_user == :all}>All Users</option>
          <%= for user <- @users do %>
            <option value={user.id} selected={@filter_user == user.id}>
              <%= user.email %>
            </option>
          <% end %>
        </select>

        <select
          phx-change="filter_status"
          id="filter_status"
          name="filter_status"
          class="custom-select custom-select-lg mb-2"
          form="filter_form"
        >
          <option value={:all} selected={@filter_status == :all}>All Statuses</option>
          <%= for status <- DatasetJob.statuses() do %>
            <option value={status} selected={@filter_status == status}>
              <%= status %>
            </option>
          <% end %>
        </select>


      </div>
    </div>

    <PagedTable.render
      filter={@query}
      table_model={@table_model}
      total_count={@total_count}
      offset={@offset}
      limit={@limit}
    />
    """
  end


  def handle_event("filter_project", %{"filter_project" => project_id}, socket) do
    project_id = String.to_integer(project_id)
    filter_by(socket, project_id, socket.assigns.filter_status, socket.assigns.filter_type, socket.assigns.filter_user, socket.assigns.table_model)
  end

  def handle_event("filter_status", %{"filter_status" => status}, socket) do
    status = String.to_existing_atom(status)
    filter_by(socket, socket.assigns.filter_project, status, socket.assigns.filter_type, socket.assigns.filter_user, socket.assigns.table_model)
  end

  def handle_event("filter_type", %{"filter_type" => type}, socket) do
    type = String.to_existing_atom(type)
    filter_by(socket, socket.assigns.filter_project, socket.assigns.filter_status, type, socket.assigns.filter_user, socket.assigns.table_model)
  end

  def handle_event("filter_user", %{"filter_user" => user_id}, socket) do
    user_id = String.to_existing_atom(user_id)
    filter_by(socket, socket.assigns.filter_project, socket.assigns.filter_status, socket.assigns.filter_type, user_id, socket.assigns.table_model)
  end

  def handle_event(event, params, socket) do
    delegate_to(
      {event, params, socket, &patch_with/2},
      [&TextSearch.handle_delegated/4, &PagedTable.handle_delegated/4]
    )
  end

  defp determine_total(items) do
    case items do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  defp is_loading?(assigns) do
    is_nil(assigns.active_rows)
  end

  def patch_with(socket, changes) do
    # convert param keys from atoms to strings
    changes = Enum.into(changes, %{}, fn {k, v} -> {Atom.to_string(k), v} end)
    # convert atom values to string values
    changes =
      Enum.into(changes, %{}, fn {k, v} ->
        case v do
          atom when is_atom(atom) -> {k, Atom.to_string(v)}
          _ -> {k, v}
        end
      end)

    table_model = SortableTableModel.update_from_params(socket.assigns.table_model, changes)

    offset = get_param(changes, "offset", 0)

    jobs =
      Datasets.browse_jobs(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        socket.assigns.options
      )

    table_model = Map.put(table_model, :rows, jobs)
    total_count = determine_total(jobs)

    {:noreply,
     assign(socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count
     )}
  end

  defp filter_by(socket, project_id, status, job_type, initiated_by_id, table_model) do
    options = %BrowseJobOptions{
      project_id: if project_id == :all do nil else project_id end,
      statuses: if status == :all do [] else [status] end,
      job_type: if job_type == :all do nil else job_type end,
      initiated_by_id: if initiated_by_id == :all do nil else initiated_by_id end
    }

    jobs =
      Datasets.browse_jobs(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, jobs)
    total_count = determine_total(jobs)

    {:noreply,
     assign(socket,
       offset: 0,
       filter_project: project_id,
       filter_status: status,
       filter_type: job_type,
       filter_user: initiated_by_id,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  defp is_disabled(selected, title) do
    if selected == title,
      do: [disabled: true],
      else: []
  end
end
