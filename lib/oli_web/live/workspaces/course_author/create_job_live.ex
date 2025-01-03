defmodule OliWeb.Workspaces.CourseAuthor.CreateJobLive do
  use OliWeb, :live_view

  import Ecto.Query
  alias Oli.Repo

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.{Accounts}
  alias Oli.Analytics.Datasets.{BrowseJobOptions, DatasetJob}
  alias Oli.Delivery.Sections.{BrowseOptions, SectionsProjectsPublications, Enrollment, Section, EnrollmentContextRole}
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Accounts.User
  alias Oli.Analytics.Datasets
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Browse
  alias OliWeb.Common.{Breadcrumb, Check, FilterBox, PagedTable, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Workspaces.CourseAuthor.Datasets.CreationTableModel
  alias OliWeb.Workspaces.CourseAuthor.Datasets.JobShortcuts
  alias Oli.Repo.{Paging, Sorting}

  @max_selected 5

  @limit 25
  @default_options %BrowseOptions{
    institution_id: nil,
    blueprint_id: nil,
    project_id: nil,
    text_search: "",
    active_today: false,
    filter_status: nil,
    filter_type: nil
  }

  @job_types [
    :datashop,
    :attempts_simple,
    :attempts_extended,
    :video,
    :page_viewed,
    :required_survey
  ]

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    %{ctx: ctx, project: project, current_author: author} = socket.assigns

    options = %{@default_options | project_id: project.id}

    sections =
      Browse.browse_sections(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        options
      )

    total_count = determine_total(sections)
    {:ok, table_model} = CreationTableModel.new(ctx, sections)

    is_admin? = Accounts.at_least_content_admin?(author)
    has_active_job? = Datasets.has_active_job?(author.id, project.id)
    can_create_job? = is_admin? or not has_active_job?

    {:ok,
     assign(socket,
       job_type: :datashop,
       shortcut: JobShortcuts.get(:datashop),
       can_create_job?: can_create_job?,
       is_admin?: is_admin?,
       sections: sections,
       table_model: table_model,
       options: options,
       total_count: total_count,
       section_ids: [],
       emails: [],
       emails_valid?: true,
       limit: @limit
     )}

  end


  def handle_params(params, _, socket) do
    table_model = SortableTableModel.update_from_params(socket.assigns.table_model, params)
    offset = get_int_param(params, "offset", 0)

    options = %BrowseOptions{
      text_search: "",
      active_today: get_boolean_param(params, "active_today", false),
      filter_status:
        get_atom_param(params, "filter_status", Ecto.Enum.values(Section, :status), nil),
      filter_type: get_atom_param(params, "filter_type", @type_opts, nil),
      # This view is currently for all institutions and all root products
      institution_id: nil,
      blueprint_id: nil,
      project_id: nil
    }

    sections =
      Browse.browse_sections(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, sections)
    total_count = determine_total(sections)

    {:noreply,
     assign(socket,
       offset: offset,
       sections: sections,
       table_model: table_model,
       total_count: total_count,
       options: options
     )}
  end

  defp section_label(section) do
    "#{section.title} (#{section.slug}) - #{section.start_date |> format_date} to #{section.end_date |> format_date}"
  end

  defp format_date(d) do
    case d do
      nil -> ""
      _ -> Timex.format!(d, "{YYYY}-{0M}-{0D}")
    end
  end


  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h2 id="header_id" class="pb-2">Create Dataset Job</h2>
    <div class="mb-3">
      <%= if !@can_create_job? do %>
        <div class="alert alert-warning flex flex-row justify-between" role="alert">
          <div>
            <strong>Warning:</strong> You already have an active job for this project,
            until it is completed you cannot create another job.
          </div>
        </div>
      <% end %>
    </div>
    <div class="mt-5 mb-3">

      <form id="job_form" />

      <p>Select the dataset type:</p>

      <select
        phx-change="job_type"
        id="job_type"
        name="job_type"
        class="custom-select custom-select-lg mb-2"
        form="job_form"
      >
        <%= for shortcut <- JobShortcuts.all() do %>
          <option value={shortcut.value} selected={@job_type == shortcut.value}>
            <%= shortcut.label %>
          </option>
        <% end %>
      </select>

      <small class="mb-3">
        <%= @shortcut.description %>
      </small>

      <%= if @is_admin? do %>

        <p class="mt-5">Enter additional emails (besides yourself) to be notified upon job termination:</p>

        <input
          type="text"
          id="emails"
          name="emails"
          class="form-control mb-2"
          form="job_form"
          phx-hook="TextInputListener"
          placeholder="Email addresses separated by commas"/>

      <% end %>

      <p class="mt-5">Select the dataset source course sections <%= if !@is_admin? do "(max 5)" else "" end %>:</p>

      <div class="mb-5" />

      <div class="sections-table">
        <PagedTable.render
          allow_selection={true}
          selection_change="section_selected"
          filter={@options.text_search}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
        />
      </div>


      <div class="mt-5">
        <button
          phx-click="create_job"
          disabled={@section_ids == [] or !@emails_valid? or !@can_create_job?}
          class="btn btn-primary"
        >
          Create Job
        </button>
      </div>

    </div>

    """
  end

  def handle_event("create_job", _params, socket) do

    # invoke the job, then redirect to the all jobs view




    {:noreply, socket}
  end

  def handle_event("change", %{"id" => "emails", "value" => emails}, socket) do

    emails = case emails do
      "" -> []
      _ -> String.split(emails, ",")
    end

    emails_valid? = Enum.all?(emails, &String.match?(&1, ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/))

    {:noreply, assign(socket, emails: emails, emails_valid?: emails_valid?)}
  end

  def handle_event("section_selected", %{"id" => id}, socket) do

    id = String.to_integer(id)

    # Toggle the selection
    section_ids = case Enum.any?(socket.assigns.section_ids, &(&1 == id)) do
      true -> Enum.reject(socket.assigns.section_ids, &(&1 == id))
      false -> [id | socket.assigns.section_ids]
    end

    # Limit the number of selected sections for non-admin users
    selection_ids = case socket.assigns.is_admin? do
      false -> Enum.take(section_ids, @max_selected)
      true -> section_ids
    end

    map_set = MapSet.new(section_ids)

    data = Map.put(socket.assigns.table_model.data, :selected_ids, map_set)
    table_model = %{socket.assigns.table_model | data: data}

    {:noreply, assign(socket, section_ids: section_ids, table_model: table_model)}
  end

  def handle_event("job_type", %{"job_type" => job_type}, socket) do

    job_type = String.to_existing_atom(job_type)
    shortcut = JobShortcuts.get(job_type)

    {:noreply, assign(socket, job_type: job_type, shortcut: shortcut)}
  end

  def handle_event(event, params, socket),
  do:
    delegate_to(
      {event, params, socket, &__MODULE__.patch_with/2},
      [&PagedTable.handle_delegated/4]
    )

  defp determine_total(projects) do
    case projects do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  defp is_disabled(selected, title) do
    if selected == title,
      do: [disabled: true],
      else: []
  end

end
