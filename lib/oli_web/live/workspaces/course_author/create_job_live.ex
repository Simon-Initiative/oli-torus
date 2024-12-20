defmodule OliWeb.Workspaces.CourseAuthor.CreateJobLive do
  use OliWeb, :live_view

  import Ecto.Query
  alias Oli.Repo

  alias Oli.{Accounts}
  alias Oli.Analytics.Datasets.{BrowseJobOptions, DatasetJob}
  alias Oli.Delivery.Sections.{BrowseOptions, SectionsProjectsPublications, Enrollment, Section, EnrollmentContextRole}
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Accounts.User
  alias Oli.Analytics.Datasets
  alias OliWeb.Common.MultiSelect.Option
  alias OliWeb.Common.MultiSelectInput
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section

  alias OliWeb.Common.{Breadcrumb, Check, FilterBox, PagedTable, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Sections.SectionsTableModel


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
    %{ctx: ctx, project: project} = socket.assigns

    options = %{@default_options | project_id: project.id}

    sections =
      Browse.browse_sections(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        options
      )

    total_count = determine_total(sections)
    {:ok, table_model} = SectionsTableModel.new(ctx, sections)

    {:ok,
     assign(socket,
       job_type: :datashop,
       sections: sections,
       table_model: table_model,
       options: options,
       total_count: total_count,
       section_ids: [],
       emails: [],
       emails_valid?: true
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
      <p>
        Create a new dataset job
      </p>
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
        <option value={:datashop} selected={@job_type == :datashop}>Datashop (.xml)</option>
        <option value={:attempts_simple} selected={@job_type == :attempts_simple}>Attempt performance data (.csv)</option>
        <option value={:attempts_extended} selected={@job_type == :attempts_extended}>Attempt performance data, with extended fields (.csv)</option>
        <option value={:video} selected={@job_type == :video}>Video interaction data (.csv)</option>
        <option value={:page_viewed} selected={@job_type == :page_viewed}>Page view data (.csv)</option>
        <option value={:required_survey} selected={@job_type == :required_survey}>Required survey data (.csv)</option>
      </select>

      <p>Enter emails to be notified upon job termination:</p>

      <input
        type="text"
        id="emails"
        name="emails"
        class="form-control mb-2"
        form="job_form"
        phx-hook="TextInputListener"
        placeholder="Email addresses separated by commas"/>

      <p>Select the dataset source course sections:</p>

      <%= for section <- @sections do %>
        <div class="flex items">
          <input
            type="checkbox"
            name="section"
            value={section.id}
            phx-click="option_selected"
            phx-target="section_selected"
            phx-value-id={section.id}
            phx-value-title={section_label(section)}
            phx-value-selected={@section_ids |> Enum.member?(section.id)}
          />
          <label for={section.id} class="ml-2"><%= section_label(section) %></label>
        </div>
      <% end %>


      <div class="mt-5">
        <button
          phx-click="create_job"
          disabled={@section_ids == [] or !@emails_valid?}
          class="btn btn-primary"
        >
          Create Job
        </button>
      </div>

    </div>

    """
  end


  @impl Phoenix.LiveView
  def handle_info({:option_selected, "section_selected", selected_ids}, socket) do
    socket =
      assign(socket,
        section_ids: selected_ids,
        form_uuid_for_product: generate_uuid(),
        product_ids: [],
        is_product: false
      )
    {:noreply, socket}
  end

  def handle_info({:option_selected, "product_selected", selected_ids}, socket) do
    socket =
      assign(socket,
        product_ids: selected_ids,
        form_uuid_for_section: generate_uuid(),
        section_ids: [],
        is_product: true
      )

    section_ids =
      Enum.reduce(selected_ids, MapSet.new(), fn id, all ->
        Map.get(socket.assigns.sections_by_product_id, id)
        |> MapSet.new()
        |> MapSet.union(all)
      end)
      |> Enum.to_list()
    {:noreply, assign(socket, section_ids: section_ids)}
  end


  def handle_event("change", %{"id" => "emails", "value" => emails}, socket) do

    emails = case emails do
      "" -> []
      _ -> String.split(emails, ",")
    end

    emails_valid? = Enum.all?(emails, &String.match?(&1, ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/))

    {:noreply, assign(socket, emails: emails, emails_valid?: emails_valid?)}
  end

  def handle_event("job_type", %{"job_type" => job_type}, socket) do
    {:noreply, assign(socket, job_type: String.to_existing_atom(job_type))}
  end

  defp get_sections_by_product_id(project_id) do
    query =
      from s in Section,
        where:
          s.base_project_id == ^project_id and not is_nil(s.blueprint_id) and
            s.type == :enrollable,
        select: {s.id, s.blueprint_id}

    Repo.all(query)
    |> Enum.reduce(%{}, fn {id, blueprint_id}, m ->
      case Map.get(m, blueprint_id) do
        nil -> Map.put(m, blueprint_id, [id])
        ids -> Map.put(m, blueprint_id, [id | ids])
      end
    end)
  end

  defp generate_uuid do
    UUID.uuid4()
  end

  defp is_disabled(selected, title) do
    if selected == title,
      do: [disabled: true],
      else: []
  end

end
