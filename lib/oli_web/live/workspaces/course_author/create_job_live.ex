defmodule OliWeb.Workspaces.CourseAuthor.CreateJobLive do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.{Accounts}
  alias Oli.Delivery.Sections.{BrowseOptions, Section}
  alias Oli.Analytics.Datasets
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Browse
  alias OliWeb.Common.{PagedTable}
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

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
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
       all_disabled: Oli.Analytics.Datasets.Settings.enabled?() == false,
       author: author,
       job_type: :datashop,
       shortcut: JobShortcuts.get(:datashop),
       can_create_job?: can_create_job?,
       required_survey_ids: [],
       is_admin?: is_admin?,
       sections: sections,
       table_model: table_model,
       options: options,
       project: project,
       total_count: total_count,
       section_ids: [],
       emails: [],
       emails_valid?: true,
       waiting: false,
       limit: @limit
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    table_model = SortableTableModel.update_from_params(socket.assigns.table_model, params)
    offset = get_int_param(params, "offset", 0)

    %{project: project} = socket.assigns

    options = %BrowseOptions{
      text_search: "",
      active_today: get_boolean_param(params, "active_today", false),
      filter_status:
        get_atom_param(params, "filter_status", Ecto.Enum.values(Section, :status), nil),
      filter_type: nil,
      institution_id: nil,
      blueprint_id: nil,
      project_id: project.id
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
      <%= if @all_disabled do %>
        <div class="alert alert-warning flex flex-row justify-between" role="alert">
          <div>
            <strong>Warning:</strong> Dataset creation is disabled.
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
        <p class="mt-5">
          Enter additional emails (besides yourself) to be notified upon job termination:
        </p>

        <input
          type="text"
          id="emails"
          name="emails"
          class="form-control mb-2"
          form="job_form"
          phx-hook="TextInputListener"
          placeholder="Email addresses separated by commas"
        />
      <% end %>

      <p class="mt-5">
        Select the dataset source course sections <%= if !@is_admin? do
          "(max 5)"
        else
          ""
        end %>:
      </p>

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
          disabled={create_job_btn_disabled?(assigns)}
          class="btn btn-primary"
        >
          Create Job
          <%= if @waiting do %>
            <span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
          <% end %>
        </button>
      </div>
    </div>
    """
  end

  defp create_job_btn_disabled?(assigns) do
    assigns.all_disabled or
      (assigns.shortcut.value == :required_survey and assigns.required_survey_ids == []) or
      assigns.waiting or
      assigns.section_ids == [] or
      !assigns.emails_valid? or
      !assigns.can_create_job?
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

    sections =
      Browse.browse_sections(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        socket.assigns.options
      )

    table_model = Map.put(table_model, :rows, sections)
    total_count = determine_total(sections)

    {:noreply,
     assign(socket,
       sections: sections,
       offset: offset,
       table_model: table_model,
       total_count: total_count
     )}
  end

  @impl true
  def handle_info({:invocation_finished, result}, socket) do
    case result do
      {:ok, _job} ->
        {:noreply,
         redirect(socket,
           to:
             Routes.live_path(
               socket,
               OliWeb.Workspaces.CourseAuthor.DatasetsLive,
               socket.assigns.project.slug
             )
         )}

      {:error, reason} ->
        # add error to the live view flash
        socket = put_flash(socket, :error, "Failed to create job: #{reason}")

        {:noreply, assign(socket, waiting: false)}
    end
  end

  @impl true
  def handle_event("create_job", _params, socket) do
    project_id = socket.assigns.project.id
    initiated_by_id = socket.assigns.author.id
    section_ids = socket.assigns.section_ids

    # Get the true job type and a default config based on the selected job shortcut
    {job_type, job_config} = JobShortcuts.configure(socket.assigns.shortcut.value, section_ids)

    # Handle the special case of the required survey shortcut, where we need to find that
    # required survey resource id and set it in the job config
    job_config =
      case socket.assigns.shortcut.value do
        :required_survey ->
          case Datasets.fetch_required_survey_ids(section_ids) do
            [] -> job_config
            required_survey_ids -> %{job_config | page_ids: required_survey_ids}
          end

        _ ->
          job_config
      end

    # Invoke the job asynchronously
    pid = self()

    Task.async(fn ->
      result = Datasets.create_job(job_type, project_id, initiated_by_id, job_config)

      send(pid, {:invocation_finished, result})
    end)

    {:noreply, assign(socket, waiting: true)}
  end

  @impl true
  def handle_event("change", %{"id" => "emails", "value" => emails}, socket) do
    emails =
      case emails do
        "" -> []
        _ -> String.split(emails, ",")
      end

    emails_valid? =
      Enum.all?(emails, &String.match?(&1, ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/))

    {:noreply, assign(socket, emails: emails, emails_valid?: emails_valid?)}
  end

  @impl true
  def handle_event("section_selected", %{"id" => id}, socket) do
    id = String.to_integer(id)

    # Toggle the selection
    section_ids =
      case Enum.any?(socket.assigns.section_ids, &(&1 == id)) do
        true -> Enum.reject(socket.assigns.section_ids, &(&1 == id))
        false -> [id | socket.assigns.section_ids]
      end

    # Limit the number of selected sections for non-admin users
    selection_ids =
      case socket.assigns.is_admin? do
        false -> Enum.take(section_ids, @max_selected)
        true -> section_ids
      end

    map_set = MapSet.new(selection_ids)

    required_survey_ids =
      case socket.assigns.shortcut.value do
        :required_survey -> Datasets.fetch_required_survey_ids(selection_ids)
        _ -> []
      end

    data = Map.put(socket.assigns.table_model.data, :selected_ids, map_set)
    table_model = %{socket.assigns.table_model | data: data}

    {:noreply,
     assign(socket,
       section_ids: section_ids,
       table_model: table_model,
       required_survey_ids: required_survey_ids
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("job_type", %{"job_type" => job_type}, socket) do
    job_type = String.to_existing_atom(job_type)
    shortcut = JobShortcuts.get(job_type)

    required_survey_ids =
      case shortcut.value do
        :required_survey -> Datasets.fetch_required_survey_ids(socket.assigns.section_ids)
        _ -> []
      end

    {:noreply,
     assign(socket,
       job_type: job_type,
       shortcut: shortcut,
       required_survey_ids: required_survey_ids
     )}
  end

  @impl true
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
end
