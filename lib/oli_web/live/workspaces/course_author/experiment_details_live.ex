defmodule OliWeb.Workspaces.CourseAuthor.ExperimentDetailsLive do
  use OliWeb, :live_view

  alias Oli.Experiments, as: ABExperiments
  alias Oli.Experiments.Scope

  @page_size 10

  @impl Phoenix.LiveView
  def mount(%{"experiment_id" => experiment_id}, _session, socket) do
    project = socket.assigns.project

    socket =
      assign(socket,
        active_view: :experiments,
        resource_slug: project.slug,
        resource_title: project.title
      )

    scope = authoring_scope(socket)

    with {:ok, experiment_id} <- parse_positive_integer(experiment_id),
         {:ok, authoring_view} <-
           ABExperiments.get_experiment_authoring_view(
             experiment_id,
             scope
           ),
         {:ok, participation} <-
           ABExperiments.get_section_participation(experiment_id, scope) do
      experiment = authoring_view.definition

      {:ok,
       assign(socket,
         experiment: experiment,
         authoring_view: authoring_view,
         option_labels: option_labels(authoring_view, scope),
         participation: participation,
         read_only: experiment.state in [:completed, :archived],
         page: 1,
         page_size: @page_size,
         participation_error: nil,
         participation_success: nil
       )}
    else
      _error ->
        {:ok,
         socket
         |> put_flash(:error, "Experiment not found.")
         |> push_navigate(
           to: ~p"/workspaces/course_author/#{socket.assigns.project.slug}/experiments"
         )}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    page = parse_page(params["page"])
    {:noreply, assign(socket, page: clamp_page(page, socket.assigns.participation))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    assigns =
      assigns
      |> assign(:page_sections, page_sections(assigns.participation, assigns.page))
      |> assign(:page_count, page_count(assigns.participation))

    ~H"""
    <div id="experiment-configuration">
      <.link
        navigate={~p"/workspaces/course_author/#{@project.slug}/experiments"}
        class="text-primary"
      >
        ← Back to experiments
      </.link>

      <div class="d-flex justify-content-between align-items-center mt-3">
        <div>
          <h2 class="mb-1">{@experiment.name}</h2>
          <p class="text-muted mb-0">Configure this experiment and section participation.</p>
        </div>
        <span class={["badge px-3 py-2", state_badge_class(@experiment.state)]}>
          {format_state(@experiment.state)}
        </span>
      </div>

      <section class="card mt-4" aria-labelledby="experiment-details-heading">
        <div class="card-header bg-white px-4 py-3">
          <h3 id="experiment-details-heading" class="h5 font-weight-bold mb-0">
            Experiment details
          </h3>
        </div>
        <div class="card-body px-4 pt-4">
          <div
            id="experiment-details-grid"
            class="mb-6 grid grid-cols-1 gap-x-8 gap-y-6 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-5"
          >
            <.detail_item label="Slug" value={@experiment.slug} monospace />
            <.detail_item
              label="Assignment policy"
              value={format_algorithm(@experiment.algorithm)}
            />
            <.detail_item
              label="Assignment unit"
              value={display_value(@experiment.assignment_unit)}
            />
            <.detail_item label="Status" value={format_state(@experiment.state)} />
            <.detail_item
              label="Decision point"
              value={decision_point_title(@authoring_view.decision_points)}
            />
            <.detail_item
              :if={@experiment.description}
              label="Description"
              value={@experiment.description}
            />
          </div>

          <div class="row">
            <div
              :if={not Enum.empty?(@authoring_view.conditions)}
              class="col-12 col-xl-6 mt-2"
            >
              <h4 class="h6 font-weight-bold mb-3">Conditions</h4>
              <div class="table-responsive">
                <table id="experiment-conditions-table" class="table table-sm table-hover mb-0">
                  <thead class="thead-light">
                    <tr>
                      <th scope="col">Condition</th>
                      <th scope="col">Option ID</th>
                      <th scope="col">Weight</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={condition <- @authoring_view.conditions}>
                      <td class="font-weight-bold">
                        {condition_label(condition, @option_labels)}
                      </td>
                      <td><span class="font-monospace text-muted">{condition.option_id}</span></td>
                      <td>{condition.weight}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            <div
              :if={map_size(@experiment.policy_config || %{}) > 0}
              class="col-12 col-xl-6 mt-2"
            >
              <h4 class="h6 font-weight-bold mb-3">Policy configuration</h4>
              <pre class="bg-light border rounded p-3 mb-0"><%= Jason.encode!(@experiment.policy_config, pretty: true) %></pre>
            </div>
          </div>
        </div>
      </section>

      <section class="card mt-4" aria-labelledby="participating-sections-heading">
        <div class="card-header bg-white px-4 py-3">
          <h3 id="participating-sections-heading" class="h5 font-weight-bold mb-0">
            Participating Sections
          </h3>
        </div>
        <div class="card-body px-4 pt-4">
          <p>Select sections to participate in this experiment.</p>

          <div :if={@participation_error} class="alert alert-danger" role="alert">
            {@participation_error}
          </div>
          <div :if={@participation_success} class="alert alert-success" role="status">
            {@participation_success}
          </div>

          <div :if={Enum.empty?(@participation.eligible_sections)} role="status">
            No active eligible sections are available.
          </div>

          <table
            :if={not Enum.empty?(@participation.eligible_sections)}
            id="participating-sections-table"
            class="table table-sm"
          >
            <caption class="sr-only">Sections eligible to participate in this experiment</caption>
            <thead>
              <tr>
                <th scope="col"><span class="sr-only">Participation selection</span></th>
                <th scope="col">Section</th>
                <th scope="col">Slug</th>
                <th scope="col">Start date</th>
                <th scope="col">End date</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={section <- @page_sections} id={"participating-section-#{section.id}"}>
                <td>
                  <input
                    type="checkbox"
                    class="form-check-input"
                    aria-label={"Set participation for #{section.title}"}
                    checked={section.id in @participation.selected_ids}
                    disabled={@read_only}
                    phx-click="toggle_section"
                    phx-value-id={section.id}
                  />
                </td>
                <td>
                  <a href={~p"/sections/#{section.slug}/manage"}>{section.title}</a>
                </td>
                <td>{section.slug}</td>
                <td>{format_date(section.start_date)}</td>
                <td>{format_date(section.end_date)}</td>
              </tr>
            </tbody>
          </table>

          <nav :if={@page_count > 1} aria-label="Participating sections pages">
            <ul class="pagination justify-content-end mb-0">
              <li class={["page-item", @page == 1 && "disabled"]}>
                <.link
                  patch={page_path(@project.slug, @experiment.id, @page - 1)}
                  class="page-link"
                  aria-disabled={@page == 1}
                >
                  Previous
                </.link>
              </li>
              <li :for={page <- 1..@page_count} class={["page-item", page == @page && "active"]}>
                <.link
                  patch={page_path(@project.slug, @experiment.id, page)}
                  class="page-link"
                  aria-current={page == @page && "page"}
                >
                  {page}
                </.link>
              </li>
              <li class={["page-item", @page == @page_count && "disabled"]}>
                <.link
                  patch={page_path(@project.slug, @experiment.id, @page + 1)}
                  class="page-link"
                  aria-disabled={@page == @page_count}
                >
                  Next
                </.link>
              </li>
            </ul>
          </nav>

          <div :if={not Enum.empty?(@participation.stale_sections)} class="alert alert-warning mt-3">
            <strong>Previously selected sections are no longer eligible:</strong>
            {Enum.map_join(@participation.stale_sections, ", ", & &1.title)}
          </div>
        </div>
      </section>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_section", %{"id" => section_id}, socket) do
    with false <- socket.assigns.read_only,
         {:ok, section_id} <- parse_positive_integer(section_id),
         true <- Enum.any?(socket.assigns.participation.eligible_sections, &(&1.id == section_id)),
         selected_ids <- toggle_id(socket.assigns.participation.selected_ids, section_id),
         {:ok, participation} <-
           ABExperiments.update_section_participation(
             socket.assigns.experiment.id,
             authoring_scope(socket),
             selected_ids
           ) do
      {:noreply,
       assign(socket,
         participation: participation,
         participation_success: "Participating sections updated.",
         participation_error: nil
       )}
    else
      {:error, error} when is_struct(error) ->
        {:noreply, assign(socket, participation_error: error.message, participation_success: nil)}

      _ ->
        {:noreply,
         assign(socket,
           participation_error: "The section selection could not be updated.",
           participation_success: nil
         )}
    end
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :monospace, :boolean, default: false

  defp detail_item(assigns) do
    ~H"""
    <div class="min-w-0">
      <div class="text-muted small text-uppercase font-weight-bold mb-1">{@label}</div>
      <div :if={@monospace} class="font-monospace">{@value}</div>
      <div :if={not @monospace}>{@value}</div>
    </div>
    """
  end

  defp option_labels(authoring_view, scope) do
    resource_ids =
      authoring_view.decision_points
      |> Enum.map(& &1.alternatives_resource_id)
      |> MapSet.new()

    case ABExperiments.list_available_decision_points(scope) do
      {:ok, candidates} ->
        candidates
        |> Enum.filter(&MapSet.member?(resource_ids, &1.alternatives_resource_id))
        |> Enum.reduce(%{}, &Map.merge(&2, &1.option_labels))

      _error ->
        %{}
    end
  end

  defp condition_label(condition, option_labels) do
    Map.get(option_labels, condition.option_id) || condition.label || condition.condition_code
  end

  defp authoring_scope(socket) do
    %Scope{
      author_id: socket.assigns.ctx.author.id,
      project_id: socket.assigns.project.id
    }
  end

  defp page_sections(participation, page) do
    participation.eligible_sections
    |> Enum.slice((page - 1) * @page_size, @page_size)
  end

  defp page_count(participation) do
    max(ceil(length(participation.eligible_sections) / @page_size), 1)
  end

  defp clamp_page(page, participation), do: min(page, page_count(participation))

  defp parse_page(value) do
    case parse_positive_integer(value || "1") do
      {:ok, page} -> page
      _ -> 1
    end
  end

  defp parse_positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> {:ok, integer}
      _ -> {:error, :invalid_integer}
    end
  end

  defp parse_positive_integer(_value), do: {:error, :invalid_integer}

  defp toggle_id(ids, id) do
    if id in ids, do: List.delete(ids, id), else: Enum.sort([id | ids])
  end

  defp page_path(project_slug, experiment_id, page) do
    "/workspaces/course_author/#{project_slug}/experiments/#{experiment_id}?page=#{max(page, 1)}"
  end

  defp format_algorithm(:weighted_random), do: "Weighted random"
  defp format_algorithm(:thompson_sampling), do: "Thompson Sampling"
  defp format_algorithm(value), do: display_value(value)

  defp format_state(value), do: display_value(value)

  defp state_badge_class(:draft), do: "badge-light border"
  defp state_badge_class(:active), do: "badge-success"
  defp state_badge_class(:completed), do: "badge-primary"
  defp state_badge_class(:archived), do: "badge-secondary"
  defp state_badge_class(_state), do: "badge-secondary"

  defp decision_point_title([decision_point | _rest]),
    do: decision_point.title || decision_point.decision_point_key

  defp decision_point_title([]), do: "—"

  defp display_value(nil), do: "—"

  defp display_value(value),
    do: value |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp format_date(nil), do: "—"
  defp format_date(%DateTime{} = value), do: Calendar.strftime(value, "%b %-d, %Y")
  defp format_date(%NaiveDateTime{} = value), do: Calendar.strftime(value, "%b %-d, %Y")
  defp format_date(%Date{} = value), do: Calendar.strftime(value, "%b %-d, %Y")
end
