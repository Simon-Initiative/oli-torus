defmodule OliWeb.Workspaces.CourseAuthor.ExperimentDetailsLive do
  use OliWeb, :live_view

  alias Oli.Experiments, as: ABExperiments
  alias Oli.Experiments.{LifecycleRequest, Scope, UpdateExperimentRequest}

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
           ABExperiments.get_section_participation(experiment_id, scope),
         {:ok, policy_snapshot} <- ABExperiments.policy_snapshot(authoring_view, scope),
         {:ok, decision_point_candidates} <- decision_point_candidates(authoring_view, scope),
         {:ok, page_options} <- ABExperiments.list_available_pages(scope) do
      experiment = authoring_view.definition

      {:ok,
       assign(socket,
         experiment: experiment,
         authoring_view: authoring_view,
         participation: participation,
         policy_snapshot: policy_snapshot,
         decision_point_candidates: decision_point_candidates,
         page_options: page_options,
         picker: nil,
         graph_draft: graph_draft(authoring_view, decision_point_candidates),
         configuration_error: nil,
         configuration_success: nil,
         read_only: experiment.state in [:completed, :archived],
         page: 1,
         page_size: @page_size,
         participation_error: nil,
         participation_success: nil,
         experiment_action_error: nil,
         experiment_action_success: nil,
         show_add_decision_point: false,
         pending_experiment_transition: nil
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
    <div id="experiment-configuration" class="dark:text-gray-100">
      <.link
        navigate={~p"/workspaces/course_author/#{@project.slug}/experiments"}
        class="text-primary"
      >
        ← Back to experiments
      </.link>

      <div class="d-flex justify-content-between align-items-center mt-3">
        <div>
          <h2 class="mb-1">{@experiment.name}</h2>
          <p class="text-muted mb-0 dark:text-gray-400">
            Configure this experiment and section participation.
          </p>
        </div>
        <div class="d-flex align-items-center gap-2">
          <button
            :if={@experiment.state in [:draft, :paused]}
            type="button"
            class="btn btn-primary"
            phx-click="start_experiment"
          >
            {if @experiment.state == :paused, do: "Resume", else: "Start"}
          </button>
          <button
            :if={@experiment.state == :active}
            type="button"
            class="btn btn-secondary"
            phx-click="pause_experiment"
          >
            Pause
          </button>
          <button
            :if={@experiment.state in [:active, :paused]}
            type="button"
            class="btn btn-primary"
            phx-click="request_experiment_transition"
            phx-value-action="complete"
          >
            Complete
          </button>
          <button
            :if={@experiment.state == :completed}
            type="button"
            class="btn btn-outline-danger"
            phx-click="request_experiment_transition"
            phx-value-action="archive"
          >
            Archive
          </button>
        </div>
      </div>

      <div :if={@experiment_action_error} class="alert alert-danger mt-3" role="alert">
        {@experiment_action_error}
      </div>
      <div :if={@experiment_action_success} class="alert alert-success mt-3" role="status">
        {@experiment_action_success}
      </div>

      <section
        class="card mt-4 dark:border-gray-700 dark:bg-neutral-800 dark:text-gray-100"
        aria-labelledby="experiment-details-heading"
      >
        <div class="card-header bg-white px-4 py-3 dark:border-gray-700 dark:bg-neutral-800">
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
              label="Assignment policies"
              value={decision_point_algorithms(@authoring_view.decision_points)}
            />
            <.detail_item
              label="Assignment unit"
              value={display_value(@experiment.assignment_unit)}
            />
            <.detail_item
              label="Status"
              value={format_state(@experiment.state)}
              badge
              badge_class={status_badge_class(@experiment.state)}
            />
            <.detail_item
              label="Decision points"
              value={Integer.to_string(length(@authoring_view.decision_points))}
            />
            <.detail_item
              :if={@experiment.description}
              label="Description"
              value={@experiment.description}
            />
          </div>

          <div class="row">
            <div :if={not Enum.empty?(@authoring_view.conditions)} class="col-12 mt-2">
              <h4 class="h6 font-weight-bold mb-3">Conditions</h4>
              <div class="table-responsive">
                <table
                  id="experiment-conditions-table"
                  class="table table-sm table-hover mb-0 dark:text-gray-100"
                >
                  <caption class="sr-only">Experiment conditions</caption>
                  <thead class="thead-light dark:bg-neutral-700 dark:text-gray-100">
                    <tr>
                      <th scope="col">Condition</th>
                      <th scope="col">Option ID</th>
                      <th scope="col">Weight</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr
                      :for={row <- condition_rows(@authoring_view)}
                      class="dark:border-gray-700 dark:hover:bg-neutral-700"
                    >
                      <td class="font-weight-bold">
                        {row.condition.label || row.condition.condition_code}
                      </td>
                      <td>
                        <span class="font-monospace text-muted dark:text-gray-400">
                          {row.mapping.option_id}
                        </span>
                      </td>
                      <td>{row.mapping.weight}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section
        id="experiment-graph-configuration"
        class="card mt-4 dark:border-gray-700 dark:bg-neutral-800 dark:text-gray-100"
        aria-labelledby="experiment-graph-heading"
      >
        <div class="card-header flex flex-col gap-1 bg-white px-4 py-3 sm:flex-row sm:items-center sm:justify-between sm:gap-4 dark:border-gray-700 dark:bg-neutral-800">
          <h3 id="experiment-graph-heading" class="h5 font-weight-bold mb-0">
            Decision-point configuration
          </h3>
          <p
            :if={@experiment.state != :draft}
            id="experiment-structure-read-only"
            class="mb-0 text-sm text-gray-500 sm:text-right dark:text-gray-400"
          >
            Experiment structure is read-only after leaving draft.
          </p>
        </div>
        <div class="card-body px-4 pt-4">
          <div :if={@configuration_error} class="alert alert-danger" role="alert">
            {@configuration_error}
          </div>
          <div :if={@configuration_success} class="alert alert-success" role="status">
            {@configuration_success}
          </div>
          <.form
            for={to_form(%{}, as: :configuration)}
            id="experiment-graph-form"
            phx-change="change_configuration"
            phx-submit="save_configuration"
          >
            <fieldset disabled={@experiment.state != :draft}>
              <legend class="sr-only">Experiment decision points and conditions</legend>
              <div class="mb-4">
                <h4 class="h6 mb-3 mt-2 font-weight-bold">Shared conditions</h4>
                <div
                  :for={{condition, condition_index} <- Enum.with_index(@graph_draft.conditions)}
                  class="mb-3 grid grid-cols-1 gap-3 md:grid-cols-3"
                >
                  <input
                    type="hidden"
                    name={"configuration[conditions][#{condition_index}][id]"}
                    value={condition.id}
                  />
                  <div>
                    <label for={"condition-#{condition_index}-label"}>Condition label</label>
                    <input
                      id={"condition-#{condition_index}-label"}
                      class="form-control"
                      name={"configuration[conditions][#{condition_index}][label]"}
                      value={condition.label}
                      required
                    />
                  </div>
                  <div>
                    <label for={"condition-#{condition_index}-code"}>Stable code</label>
                    <input
                      id={"condition-#{condition_index}-code"}
                      class="form-control disabled:cursor-not-allowed disabled:opacity-60"
                      value={condition.condition_code}
                      disabled
                    />
                  </div>
                  <div>
                    <label for={"condition-#{condition_index}-active"}>Availability</label>
                    <select
                      id={"condition-#{condition_index}-active"}
                      class="form-control"
                      name={"configuration[conditions][#{condition_index}][active]"}
                    >
                      <option value="true" selected={condition.active}>Active</option>
                      <option value="false" selected={not condition.active}>Inactive</option>
                    </select>
                  </div>
                </div>
              </div>

              <div
                :for={{point, point_index} <- Enum.with_index(@graph_draft.decision_points)}
                id={"decision-point-config-#{point_index}"}
                class="mb-4 rounded border p-4 dark:border-gray-700"
              >
                <input
                  type="hidden"
                  name={"configuration[decision_points][#{point_index}][alternatives_resource_id]"}
                  value={point.alternatives_resource_id}
                />
                <input
                  type="hidden"
                  name={"configuration[decision_points][#{point_index}][decision_point_key]"}
                  value={point.decision_point_key}
                />
                <input
                  type="hidden"
                  name={"configuration[decision_points][#{point_index}][title]"}
                  value={point.title}
                />
                <div :if={point.algorithm == :weighted_random}>
                  <input
                    :for={
                      {key, value} <- [
                        {"prior_alpha", point.prior_alpha},
                        {"prior_beta", point.prior_beta},
                        {"warm_up_assignments", point.warm_up_assignments},
                        {"max_condition_share", point.max_condition_share},
                        {"fixed_control_allocation", point.fixed_control_allocation},
                        {"imbalance_threshold", point.imbalance_threshold}
                      ]
                    }
                    type="hidden"
                    name={"configuration[decision_points][#{point_index}][#{key}]"}
                    value={value}
                  />
                </div>
                <div class="d-flex justify-content-between align-items-center gap-2">
                  <h4 class="h6 font-weight-bold mb-0">{point.title}</h4>
                  <button
                    :if={@experiment.state == :draft}
                    type="button"
                    class="btn btn-outline-danger btn-sm"
                    phx-click="remove_draft_decision_point"
                    phx-value-index={point_index}
                  >
                    Remove decision point
                  </button>
                </div>
                <div class="mt-3 grid grid-cols-1 gap-3 md:grid-cols-2">
                  <div>
                    <label for={"decision-point-#{point_index}-algorithm"}>Assignment policy</label>
                    <select
                      id={"decision-point-#{point_index}-algorithm"}
                      class="form-control"
                      name={"configuration[decision_points][#{point_index}][algorithm]"}
                    >
                      <option value="weighted_random" selected={point.algorithm == :weighted_random}>
                        Weighted random
                      </option>
                      <option
                        value="thompson_sampling"
                        selected={point.algorithm == :thompson_sampling}
                      >
                        Thompson Sampling
                      </option>
                    </select>
                  </div>
                  <div :for={{mapping, mapping_index} <- Enum.with_index(point.mappings)}>
                    <input
                      type="hidden"
                      name={"configuration[decision_points][#{point_index}][mappings][#{mapping_index}][condition_id]"}
                      value={mapping.condition_id}
                    />
                    <label for={"mapping-#{point_index}-#{mapping_index}-option"}>
                      {mapping.condition_label} option
                    </label>
                    <select
                      id={"mapping-#{point_index}-#{mapping_index}-option"}
                      class="form-control"
                      name={"configuration[decision_points][#{point_index}][mappings][#{mapping_index}][option_id]"}
                    >
                      <option
                        :for={{label, option_id} <- mapping.options}
                        value={option_id}
                        selected={mapping.option_id == option_id}
                      >
                        {label}
                      </option>
                    </select>
                    <label for={"mapping-#{point_index}-#{mapping_index}-weight"}>Weight</label>
                    <input
                      id={"mapping-#{point_index}-#{mapping_index}-weight"}
                      type="number"
                      min="0"
                      step="any"
                      class="form-control"
                      name={"configuration[decision_points][#{point_index}][mappings][#{mapping_index}][weight]"}
                      value={mapping.weight}
                      required
                    />
                  </div>
                </div>
                <div :if={point.algorithm == :thompson_sampling} class="mt-3">
                  <h5 class="h6 mb-3 mt-4 font-weight-bold">
                    Assignment policy and guardrails
                  </h5>
                  <p class="mb-3 text-sm text-gray-500 dark:text-gray-400">
                    These settings apply only to this decision point.
                  </p>
                  <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
                    <div>
                      <label for={"point-#{point_index}-reward-source"}>Reward source</label>
                      <input
                        id={"point-#{point_index}-reward-source"}
                        class="form-control disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500 dark:disabled:bg-gray-700 dark:disabled:text-gray-400"
                        value="Assessment page normalized score"
                        disabled
                      />
                    </div>
                    <.number_field
                      point_index={point_index}
                      key="prior_alpha"
                      label="Prior alpha"
                      help="Alpha represents prior and observed successful outcomes. Higher values increase the estimated success probability."
                      value={point.prior_alpha}
                      min="0.0001"
                      max="1000"
                    />
                    <.number_field
                      point_index={point_index}
                      key="prior_beta"
                      label="Prior beta"
                      help="Beta represents prior and observed unsuccessful outcomes. Higher values decrease the estimated success probability."
                      value={point.prior_beta}
                      min="0.0001"
                      max="1000"
                    />
                    <.number_field
                      point_index={point_index}
                      key="warm_up_assignments"
                      label="Warm-up assignments"
                      help="The minimum assignment count collected before adaptive allocation begins."
                      value={point.warm_up_assignments}
                      min="0"
                      step="1"
                    />
                    <.number_field
                      point_index={point_index}
                      key="max_condition_share"
                      label="Max condition share"
                      help="The traffic cap limits the largest share of assignments any one condition may receive."
                      value={point.max_condition_share}
                      min="0.0001"
                      max="1"
                    />
                    <.number_field
                      point_index={point_index}
                      key="fixed_control_allocation"
                      label="Fixed-control allocation"
                      help="The target share reserved for the control condition while the fixed-control guardrail is active."
                      value={point.fixed_control_allocation}
                      min="0"
                      max="1"
                      required={false}
                    />
                    <.number_field
                      point_index={point_index}
                      key="imbalance_threshold"
                      label="Imbalance warning threshold"
                      help="Shows a warning when a condition's observed assignment share differs from an even allocation by more than this amount."
                      value={point.imbalance_threshold}
                      min="0"
                      max="1"
                    />
                  </div>
                </div>
                <div class="mt-3">
                  <h5 class="h6 mb-3 mt-4 font-weight-bold">Interventions and assessments</h5>
                  <div
                    :for={{intervention, intervention_index} <- Enum.with_index(point.interventions)}
                    class="mb-3 grid grid-cols-1 gap-3 rounded border p-3 md:grid-cols-[repeat(4,minmax(0,1fr))_auto] dark:border-gray-700"
                  >
                    <.selector_field
                      point_index={point_index}
                      intervention_index={intervention_index}
                      key="page_resource_id"
                      label="Intervention page"
                      value={intervention.page_resource_id}
                      display_value={page_option_label(@page_options, intervention.page_resource_id)}
                      picker_kind="intervention_page"
                      disabled={@experiment.state != :draft}
                    />
                    <.selector_field
                      point_index={point_index}
                      intervention_index={intervention_index}
                      key="content_element_id"
                      label="Placement element ID"
                      value={intervention.content_element_id}
                      display_value={intervention.content_element_id}
                      picker_kind="placement_element"
                      disabled={@experiment.state != :draft or is_nil(intervention.page_resource_id)}
                    />
                    <.selector_field
                      point_index={point_index}
                      intervention_index={intervention_index}
                      key="assessment_page_resource_id"
                      label="Scored page"
                      value={intervention.assessment_page_resource_id}
                      display_value={
                        page_option_label(@page_options, intervention.assessment_page_resource_id)
                      }
                      picker_kind="assessment_page"
                      required={false}
                      disabled={@experiment.state != :draft}
                    />
                    <.text_field
                      point_index={point_index}
                      intervention_index={intervention_index}
                      key="reward_threshold"
                      label="Success threshold"
                      value={intervention.reward_threshold}
                      required={false}
                      disabled={@experiment.state != :draft}
                    />
                    <button
                      :if={@experiment.state == :draft}
                      id={"remove-intervention-#{point_index}-#{intervention_index}"}
                      type="button"
                      class="mt-6 inline-flex h-[42px] w-[42px] self-start items-center justify-center rounded-md text-red-600 hover:bg-red-50 hover:text-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 dark:text-red-400 dark:hover:bg-red-950/30"
                      phx-click="remove_draft_intervention"
                      phx-value-point-index={point_index}
                      phx-value-intervention-index={intervention_index}
                      phx-hook="GlobalTooltip"
                      data-tooltip="Remove intervention"
                      data-tooltip-style="body"
                      aria-label="Remove intervention"
                    >
                      <i class="fa-solid fa-trash" aria-hidden="true"></i>
                    </button>
                  </div>
                  <button
                    :if={@experiment.state == :draft}
                    type="button"
                    class="btn btn-link px-0"
                    phx-click="add_draft_intervention"
                    phx-value-index={point_index}
                  >
                    Add intervention
                  </button>
                </div>
              </div>

              <div>
                <button
                  :if={
                    @experiment.state == :draft and
                      unused_candidates(@graph_draft, @decision_point_candidates) != []
                  }
                  type="button"
                  class="btn btn-outline-primary"
                  phx-click="open_add_decision_point"
                >
                  Add decision point
                </button>
              </div>
              <div :if={@experiment.state == :draft} class="mt-4 flex justify-end">
                <button type="submit" class="btn btn-primary">
                  Save configuration
                </button>
              </div>
            </fieldset>
          </.form>
        </div>
      </section>

      <section
        :if={show_policy_report?(@experiment, @policy_snapshot)}
        id="experiment-policy-report"
        class="card mt-4 dark:border-gray-700 dark:bg-neutral-800 dark:text-gray-100"
        aria-labelledby="experiment-policy-report-heading"
      >
        <div class="card-header bg-white px-4 py-3 dark:border-gray-700 dark:bg-neutral-800">
          <div class="d-flex justify-content-between align-items-center gap-3">
            <div>
              <h3 id="experiment-policy-report-heading" class="h5 font-weight-bold mb-1">
                Thompson Sampling policy
              </h3>
              <p class="text-muted mb-0 dark:text-gray-400">
                Current bounded policy state. Allocation is observed traffic, not a prediction.
              </p>
            </div>
            <button
              type="button"
              class="btn btn-link d-inline-flex align-items-center gap-2 px-0"
              phx-click="refresh_policy_snapshot"
              phx-disable-with="Refreshing…"
            >
              <.icon name="fa-solid fa-rotate-right" class="h-4 w-4" /> Refresh
            </button>
          </div>
        </div>
        <div class="card-body px-4 pt-4">
          <div :if={@experiment.state in [:paused, :completed, :archived]} class="alert alert-info">
            {lifecycle_policy_message(@experiment.state)}
          </div>
          <div id="policy-snapshot-table-scroll" class="overflow-x-auto">
            <table id="policy-snapshot-table" class="table table-sm dark:text-gray-100">
              <caption class="sr-only">Current Thompson Sampling condition policy state</caption>
              <thead>
                <tr>
                  <th scope="col">Condition</th>
                  <th scope="col">
                    <.technical_term
                      id="estimated-success-probability-help"
                      label="Estimated success probability"
                      help="The posterior mean: alpha divided by alpha plus beta. It summarizes observed evidence and configured priors; it is not the probability of the next assignment."
                    />
                  </th>
                  <th scope="col">Accepted successes</th>
                  <th scope="col">Accepted failures</th>
                  <th scope="col">Observed assignments</th>
                  <th scope="col">
                    <.technical_term
                      id="observed-share-help"
                      label="Observed share"
                      help="The percentage of recorded assignments at this decision point that went to this condition."
                    />
                  </th>
                  <th scope="col">
                    <.technical_term
                      id="policy-status-help"
                      label="Policy status"
                      help="The guardrail currently governing allocation. Traffic cap prevents a condition from exceeding its configured maximum share."
                    />
                  </th>
                  <th scope="col">Last updated</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={row <- @policy_snapshot}
                  id={"policy-condition-#{row.decision_point_id}-#{row.condition_id}"}
                >
                  <td>{row.condition_label}</td>
                  <td>{format_percent(row.estimated_success_probability)}</td>
                  <td>{row.accepted_success_count}</td>
                  <td>{row.accepted_failure_count}</td>
                  <td>{row.assignment_count}</td>
                  <td>{format_percent(row.assignment_share)}</td>
                  <td>
                    <.technical_term
                      id={"policy-mode-help-#{row.decision_point_id}-#{row.condition_id}"}
                      label={format_policy_mode(row.effective_mode)}
                      help={policy_mode_help(row.effective_mode)}
                    />
                  </td>
                  <td>{format_snapshot_datetime(row.updated_at)}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div :for={row <- @policy_snapshot} class="mt-3">
            <div class="text-muted small dark:text-gray-400">
              {guardrail_progress(row)}
            </div>
            <div :if={row.imbalance_warning?} class="alert alert-warning" role="status">
              Assignment imbalance monitoring threshold exceeded for {row.condition_label}.
            </div>
            <details id={"policy-technical-details-#{row.condition_id}"}>
              <summary>Technical details for {row.condition_label}</summary>
              <dl class="mt-2 grid grid-cols-2 gap-2 sm:max-w-sm">
                <dt>
                  <.technical_term
                    id={"posterior-alpha-help-#{row.decision_point_id}-#{row.condition_id}"}
                    label="Posterior α"
                    help="Alpha is the accumulated successful evidence plus the configured prior alpha."
                  />
                </dt>
                <dd>{row.posterior_alpha}</dd>
                <dt>
                  <.technical_term
                    id={"posterior-beta-help-#{row.decision_point_id}-#{row.condition_id}"}
                    label="Posterior β"
                    help="Beta is the accumulated unsuccessful evidence plus the configured prior beta."
                  />
                </dt>
                <dd>{row.posterior_beta}</dd>
              </dl>
            </details>
          </div>
        </div>
      </section>

      <section
        class="card mt-4 dark:border-gray-700 dark:bg-neutral-800 dark:text-gray-100"
        aria-labelledby="participating-sections-heading"
      >
        <div class="card-header bg-white px-4 py-3 dark:border-gray-700 dark:bg-neutral-800">
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

          <div
            :if={not Enum.empty?(@participation.eligible_sections)}
            id="participating-sections-table-scroll"
            class="overflow-x-auto"
          >
            <table id="participating-sections-table" class="table table-sm dark:text-gray-100">
              <caption class="sr-only">Sections eligible to participate in this experiment</caption>
              <thead class="dark:border-gray-700 dark:bg-neutral-700 dark:text-gray-100">
                <tr>
                  <th scope="col"><span class="sr-only">Participation selection</span></th>
                  <th scope="col">Section</th>
                  <th scope="col">Slug</th>
                  <th scope="col">Start date</th>
                  <th scope="col">End date</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={section <- @page_sections}
                  id={"participating-section-#{section.id}"}
                  class="dark:border-gray-700"
                >
                  <td>
                    <input
                      type="checkbox"
                      class="form-check-input disabled:cursor-not-allowed disabled:opacity-50"
                      aria-label={"Set participation for #{section.title}"}
                      aria-disabled={to_string(@read_only)}
                      checked={section.id in @participation.selected_ids}
                      disabled={@read_only}
                      phx-click="toggle_section"
                      phx-value-id={section.id}
                    />
                  </td>
                  <td>
                    <a
                      class="text-primary dark:text-blue-300"
                      href={~p"/sections/#{section.slug}/manage"}
                    >
                      {section.title}
                    </a>
                  </td>
                  <td>{section.slug}</td>
                  <td>{format_date(section.start_date)}</td>
                  <td>{format_date(section.end_date)}</td>
                </tr>
              </tbody>
            </table>
          </div>

          <nav :if={@page_count > 1} aria-label="Participating sections pages">
            <ul class="pagination justify-content-end mb-0">
              <li class={["page-item", @page == 1 && "disabled"]}>
                <span
                  :if={@page == 1}
                  id="participating-sections-previous"
                  class="page-link dark:border-gray-700 dark:bg-neutral-800 dark:text-blue-300"
                  aria-disabled="true"
                >
                  Previous
                </span>
                <.link
                  :if={@page > 1}
                  id="participating-sections-previous"
                  patch={page_path(@project.slug, @experiment.id, @page - 1)}
                  class="page-link dark:border-gray-700 dark:bg-neutral-800 dark:text-blue-300"
                >
                  Previous
                </.link>
              </li>
              <li :for={page <- 1..@page_count} class={["page-item", page == @page && "active"]}>
                <.link
                  patch={page_path(@project.slug, @experiment.id, page)}
                  class={[
                    "page-link dark:border-gray-700 dark:bg-neutral-800 dark:text-blue-300",
                    page == @page && "dark:!bg-primary dark:!text-white"
                  ]}
                  aria-current={page == @page && "page"}
                >
                  {page}
                </.link>
              </li>
              <li class={["page-item", @page == @page_count && "disabled"]}>
                <span
                  :if={@page == @page_count}
                  id="participating-sections-next"
                  class="page-link dark:border-gray-700 dark:bg-neutral-800 dark:text-blue-300"
                  aria-disabled="true"
                >
                  Next
                </span>
                <.link
                  :if={@page < @page_count}
                  id="participating-sections-next"
                  patch={page_path(@project.slug, @experiment.id, @page + 1)}
                  class="page-link dark:border-gray-700 dark:bg-neutral-800 dark:text-blue-300"
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

      <OliWeb.Live.Common.FilteredOptionPicker.filtered_option_picker
        :if={@picker}
        id="experiment-option-picker"
        title={@picker.title}
        label={@picker.label}
        description={Map.get(@picker, :description)}
        options={@picker.options}
        filter={@picker.filter}
        description_key={Map.get(@picker, :description_key)}
        position_key={Map.get(@picker, :position_key)}
        selection_mode={@picker.selection_mode}
        selected_values={@picker.selected_values}
        page={@picker.page}
        page_size={@picker.page_size}
        on_toggle="toggle_picker_option"
        on_page="change_picker_page"
        on_select="select_picker_option"
        on_cancel="close_picker"
      />

      <OliWeb.Components.Modal.modal
        :if={@show_add_decision_point}
        id="add-decision-point-modal"
        show={true}
        header_level={2}
        wrapper_class="w-full max-w-lg p-4"
        on_cancel={Phoenix.LiveView.JS.push("close_add_decision_point")}
      >
        <:title>Add decision point</:title>
        <.form
          for={to_form(%{}, as: :decision_point)}
          id="add-decision-point-form"
          phx-submit="add_draft_decision_point"
        >
          <div class="form-group">
            <label for="decision-point-candidate-select">
              Experiment-Controlled Alternatives Group
            </label>
            <select
              id="decision-point-candidate-select"
              class="form-control"
              name="decision_point[resource_id]"
              required
            >
              <option value="" selected disabled>Select a group</option>
              <option
                :for={candidate <- unused_candidates(@graph_draft, @decision_point_candidates)}
                value={candidate.alternatives_resource_id}
              >
                {candidate.title}
              </option>
            </select>
          </div>
          <div class="mt-4 flex justify-end gap-2">
            <button type="button" class="btn btn-link" phx-click="close_add_decision_point">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">Add decision point</button>
          </div>
        </.form>
      </OliWeb.Components.Modal.modal>

      <OliWeb.Components.Modal.modal
        :if={@pending_experiment_transition}
        id="confirm-experiment-transition-modal"
        show={true}
        header_level={2}
        wrapper_class="w-full max-w-lg p-4"
        on_cancel={Phoenix.LiveView.JS.push("cancel_experiment_transition")}
      >
        <:title>{transition_title(@pending_experiment_transition)}</:title>
        <p>{transition_confirmation(@experiment, @pending_experiment_transition)}</p>
        <:custom_footer>
          <div class="d-flex justify-content-end gap-2 p-4 pt-0">
            <button type="button" class="btn btn-link" phx-click="cancel_experiment_transition">
              Cancel
            </button>
            <button
              type="button"
              class={[
                "btn",
                if(@pending_experiment_transition == :archive,
                  do: "btn-danger",
                  else: "btn-primary"
                )
              ]}
              phx-click="confirm_experiment_transition"
            >
              {transition_button_label(@pending_experiment_transition)}
            </button>
          </div>
        </:custom_footer>
      </OliWeb.Components.Modal.modal>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("start_experiment", _params, socket) do
    transition_experiment(socket, :start)
  end

  def handle_event("pause_experiment", _params, socket) do
    transition_experiment(socket, :pause)
  end

  def handle_event("request_experiment_transition", %{"action" => action}, socket) do
    with {:ok, action} <- parse_confirmation_action(action),
         true <- transition_available?(socket.assigns.experiment.state, action) do
      {:noreply,
       assign(socket,
         pending_experiment_transition: action,
         experiment_action_error: nil
       )}
    else
      _ ->
        {:noreply,
         assign(socket, experiment_action_error: "The requested action is not available.")}
    end
  end

  def handle_event("cancel_experiment_transition", _params, socket) do
    {:noreply, assign(socket, pending_experiment_transition: nil)}
  end

  def handle_event("confirm_experiment_transition", _params, socket) do
    case socket.assigns.pending_experiment_transition do
      action when action in [:complete, :archive] ->
        socket
        |> assign(pending_experiment_transition: nil)
        |> transition_experiment(action)

      nil ->
        {:noreply, assign(socket, experiment_action_error: "No experiment action is pending.")}
    end
  end

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

  def handle_event("refresh_policy_snapshot", _params, socket) do
    scope = authoring_scope(socket)

    with {:ok, authoring_view} <-
           ABExperiments.get_experiment_authoring_view(socket.assigns.experiment.id, scope),
         {:ok, snapshot} <- ABExperiments.policy_snapshot(authoring_view, scope) do
      {:noreply, assign(socket, authoring_view: authoring_view, policy_snapshot: snapshot)}
    else
      {:error, error} -> {:noreply, assign(socket, experiment_action_error: error.message)}
    end
  end

  def handle_event("open_add_decision_point", _params, socket) do
    candidates =
      unused_candidates(socket.assigns.graph_draft, socket.assigns.decision_point_candidates)

    case socket.assigns.experiment.state == :draft and candidates != [] do
      true -> {:noreply, assign(socket, show_add_decision_point: true)}
      false -> invalid_configuration_event(socket)
    end
  end

  def handle_event("close_add_decision_point", _params, socket) do
    {:noreply, assign(socket, show_add_decision_point: false)}
  end

  def handle_event(
        "open_option_picker",
        %{
          "kind" => kind,
          "point-index" => point_index,
          "intervention-index" => intervention_index
        },
        socket
      ) do
    with :draft <- socket.assigns.experiment.state,
         {:ok, point_index} <- parse_index(point_index),
         {:ok, intervention_index} <- parse_index(intervention_index),
         {:ok, picker} <- build_picker(socket, kind, point_index, intervention_index) do
      {:noreply, assign(socket, picker: picker)}
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event("close_picker", _params, socket), do: {:noreply, assign(socket, picker: nil)}

  def handle_event("toggle_picker_option", %{"id" => value}, socket) do
    with picker when not is_nil(picker) <- socket.assigns.picker do
      selected_values =
        case picker.selection_mode do
          :single -> [value]
          :multiple -> toggle_picker_value(picker.selected_values, value)
        end

      {:noreply, assign(socket, picker: %{picker | selected_values: selected_values})}
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event("change_picker_page", %{"offset" => offset}, socket) do
    with picker when not is_nil(picker) <- socket.assigns.picker,
         {:ok, offset} <- parse_non_negative_integer(offset) do
      page = div(offset, picker.page_size) + 1
      {:noreply, assign(socket, picker: %{picker | page: page})}
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event("select_picker_option", _params, socket) do
    with %{point_index: point_index, intervention_index: intervention_index, key: key} <-
           socket.assigns.picker,
         [value] <- socket.assigns.picker.selected_values,
         {:ok, parsed_value} <- parse_picker_value(key, value) do
      socket = assign(socket, picker: nil, configuration_error: nil)

      update_graph_points(socket, fn points ->
        List.update_at(points, point_index, fn point ->
          interventions =
            List.update_at(point.interventions, intervention_index, fn intervention ->
              intervention
              |> Map.put(key, parsed_value)
              |> maybe_clear_element_selection(key)
            end)

          %{point | interventions: interventions}
        end)
      end)
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event(
        "add_draft_decision_point",
        %{"decision_point" => %{"resource_id" => resource_id}},
        socket
      ) do
    with :draft <- socket.assigns.experiment.state,
         {:ok, resource_id} <- parse_positive_integer(resource_id),
         candidate when not is_nil(candidate) <-
           Enum.find(
             unused_candidates(
               socket.assigns.graph_draft,
               socket.assigns.decision_point_candidates
             ),
             &(&1.alternatives_resource_id == resource_id)
           ) do
      point = draft_point(candidate, socket.assigns.graph_draft.conditions)

      {:noreply,
       socket
       |> assign(show_add_decision_point: false, configuration_error: nil)
       |> update(:graph_draft, fn draft ->
         %{draft | decision_points: draft.decision_points ++ [point]}
       end)}
    else
      _ -> {:noreply, assign(socket, configuration_error: "Decision point could not be added.")}
    end
  end

  def handle_event("remove_draft_decision_point", %{"index" => index}, socket) do
    with {:ok, index} <- parse_index(index) do
      update_draft_list(socket, :decision_points, index, &List.delete_at(&1, index))
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event("add_draft_intervention", %{"index" => index}, socket) do
    with {:ok, index} <- parse_index(index) do
      update_graph_points(socket, fn points ->
        List.update_at(points, index, fn point ->
          %{point | interventions: point.interventions ++ [empty_intervention()]}
        end)
      end)
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event(
        "remove_draft_intervention",
        %{"point-index" => point_index, "intervention-index" => intervention_index},
        socket
      ) do
    with {:ok, point_index} <- parse_index(point_index),
         {:ok, intervention_index} <- parse_index(intervention_index) do
      update_graph_points(socket, fn points ->
        List.update_at(points, point_index, fn point ->
          %{point | interventions: List.delete_at(point.interventions, intervention_index)}
        end)
      end)
    else
      _ -> invalid_configuration_event(socket)
    end
  end

  def handle_event("save_configuration", %{"configuration" => params}, socket) do
    with :draft <- socket.assigns.experiment.state,
         {:ok, request} <- configuration_request(socket, params),
         {:ok, experiment} <-
           ABExperiments.update_experiment(socket.assigns.experiment.id, request),
         {:ok, authoring_view} <-
           ABExperiments.get_experiment_authoring_view(experiment.id, authoring_scope(socket)) do
      {:noreply,
       assign(socket,
         experiment: experiment,
         authoring_view: authoring_view,
         graph_draft: graph_draft(authoring_view, socket.assigns.decision_point_candidates),
         configuration_success: "Experiment configuration saved.",
         configuration_error: nil
       )}
    else
      {:error, %Oli.Experiments.ExperimentError{} = error} ->
        {:noreply, assign(socket, configuration_error: error.message, configuration_success: nil)}

      {:error, message} when is_binary(message) ->
        {:noreply, assign(socket, configuration_error: message, configuration_success: nil)}

      _ ->
        {:noreply,
         assign(socket,
           configuration_error: "Experiment configuration is read-only.",
           configuration_success: nil
         )}
    end
  end

  def handle_event("change_configuration", %{"configuration" => params}, socket) do
    case socket.assigns.experiment.state do
      :draft ->
        condition_changes = submitted_condition_changes(params["conditions"])
        point_changes = submitted_point_changes(params["decision_points"])

        {:noreply,
         update(socket, :graph_draft, fn draft ->
           draft
           |> Map.update!(:conditions, &merge_indexed_changes(&1, condition_changes))
           |> Map.update!(:decision_points, &merge_indexed_changes(&1, point_changes))
         end)}

      _ ->
        {:noreply, socket}
    end
  end

  defp transition_experiment(socket, action) do
    request = %LifecycleRequest{scope: authoring_scope(socket)}

    result =
      case action do
        :start -> ABExperiments.activate_experiment(socket.assigns.experiment.id, request)
        :pause -> ABExperiments.pause_experiment(socket.assigns.experiment.id, request)
        :complete -> ABExperiments.complete_experiment(socket.assigns.experiment.id, request)
        :archive -> ABExperiments.archive_experiment(socket.assigns.experiment.id, request)
      end

    case result do
      {:ok, experiment} ->
        authoring_view = %{socket.assigns.authoring_view | definition: experiment}

        socket =
          assign(socket,
            experiment: experiment,
            authoring_view: authoring_view,
            read_only: experiment.state in [:completed, :archived],
            experiment_action_success: "Experiment updated.",
            experiment_action_error: nil
          )

        case ABExperiments.policy_snapshot(authoring_view, authoring_scope(socket)) do
          {:ok, policy_snapshot} -> {:noreply, assign(socket, policy_snapshot: policy_snapshot)}
          {:error, error} -> {:noreply, assign(socket, experiment_action_error: error.message)}
        end

      {:error, %Oli.Experiments.ExperimentError{} = error} ->
        {:noreply,
         assign(socket,
           experiment_action_error: error.message,
           experiment_action_success: nil
         )}
    end
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :monospace, :boolean, default: false
  attr :badge, :boolean, default: false
  attr :badge_class, :string, default: "badge-secondary"

  defp detail_item(assigns) do
    ~H"""
    <div class="min-w-0">
      <div class="text-muted small text-uppercase font-weight-bold mb-1 dark:text-gray-400">
        {@label}
      </div>
      <div :if={@monospace} class="font-monospace">{@value}</div>
      <span :if={@badge} class={["badge", @badge_class]}>{@value}</span>
      <div :if={not @monospace and not @badge}>{@value}</div>
    </div>
    """
  end

  attr :point_index, :integer, required: true
  attr :key, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :min, :string, required: true
  attr :max, :string, default: nil
  attr :step, :string, default: "any"
  attr :required, :boolean, default: true
  attr :help, :string, default: nil

  defp number_field(assigns) do
    ~H"""
    <div>
      <label for={"point-#{@point_index}-#{@key}"}>
        <.technical_term
          :if={@help}
          id={"point-#{@point_index}-#{@key}-help"}
          label={@label}
          help={@help}
        />
        <span :if={is_nil(@help)}>{@label}</span>
      </label>
      <input
        id={"point-#{@point_index}-#{@key}"}
        type="number"
        class="form-control disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500 dark:disabled:bg-gray-700 dark:disabled:text-gray-400"
        name={"configuration[decision_points][#{@point_index}][#{@key}]"}
        value={@value}
        min={@min}
        max={@max}
        step={@step}
        required={@required}
      />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :help, :string, required: true

  defp technical_term(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1">
      <span>{@label}</span>
      <span
        id={@id}
        class="inline-flex cursor-help text-gray-500 dark:text-gray-400"
        phx-hook="GlobalTooltip"
        data-tooltip={@help}
        data-tooltip-style="body"
        data-tooltip-stop-propagation="true"
        tabindex="0"
        role="img"
        aria-label={"About #{@label}: #{@help}"}
      >
        <.icon name="fa-solid fa-circle-info" class="h-3.5 w-3.5" />
      </span>
    </span>
    """
  end

  attr :point_index, :integer, required: true
  attr :intervention_index, :integer, required: true
  attr :key, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :required, :boolean, default: true
  attr :disabled, :boolean, default: false

  defp text_field(assigns) do
    ~H"""
    <div>
      <label for={"intervention-#{@point_index}-#{@intervention_index}-#{@key}"}>{@label}</label>
      <input
        id={"intervention-#{@point_index}-#{@intervention_index}-#{@key}"}
        class="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-gray-900 shadow-sm outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500 disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:disabled:bg-gray-700 dark:disabled:text-gray-400"
        name={"configuration[decision_points][#{@point_index}][interventions][#{@intervention_index}][#{@key}]"}
        value={@value}
        required={@required}
        disabled={@disabled}
      />
    </div>
    """
  end

  attr :point_index, :integer, required: true
  attr :intervention_index, :integer, required: true
  attr :key, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :display_value, :any, required: true
  attr :picker_kind, :string, required: true
  attr :required, :boolean, default: true
  attr :disabled, :boolean, default: false

  defp selector_field(assigns) do
    ~H"""
    <div>
      <label for={"intervention-#{@point_index}-#{@intervention_index}-#{@key}"}>{@label}</label>
      <input
        type="hidden"
        name={"configuration[decision_points][#{@point_index}][interventions][#{@intervention_index}][#{@key}]"}
        value={@value}
      />
      <div class="flex w-full">
        <input
          id={"intervention-#{@point_index}-#{@intervention_index}-#{@key}"}
          class={[
            "min-w-0 flex-1 rounded-l-md rounded-r-none border border-r-0 border-gray-300 bg-white px-3 py-2 text-gray-900 shadow-sm outline-none focus:z-10 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 dark:disabled:bg-gray-700 dark:disabled:text-gray-400",
            @disabled && "cursor-not-allowed",
            !@disabled && "cursor-pointer"
          ]}
          value={@display_value || "Not selected"}
          readonly
          disabled={@disabled}
          aria-required={to_string(@required)}
          aria-haspopup="dialog"
          phx-click={if @disabled, do: nil, else: "open_option_picker"}
          phx-value-kind={@picker_kind}
          phx-value-point-index={@point_index}
          phx-value-intervention-index={@intervention_index}
        />
        <button
          type="button"
          class="whitespace-nowrap rounded-l-none rounded-r-md border border-blue-600 bg-white px-3 py-2 font-medium text-blue-700 shadow-sm hover:bg-blue-50 focus:z-10 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:cursor-not-allowed disabled:border-gray-300 disabled:bg-gray-100 disabled:text-gray-400 dark:bg-gray-800 dark:text-blue-300 dark:hover:bg-gray-700"
          phx-click="open_option_picker"
          phx-value-kind={@picker_kind}
          phx-value-point-index={@point_index}
          phx-value-intervention-index={@intervention_index}
          disabled={@disabled}
          aria-haspopup="dialog"
        >
          Choose…
        </button>
      </div>
    </div>
    """
  end

  defp graph_draft(authoring_view, candidates) do
    conditions = authoring_view.conditions
    candidate_by_resource = Map.new(candidates, &{&1.alternatives_resource_id, &1})
    mappings_by_point = Enum.group_by(authoring_view.mappings, & &1.decision_point_id)
    interventions_by_point = Enum.group_by(authoring_view.interventions, & &1.decision_point_id)

    bindings_by_intervention =
      Map.new(authoring_view.assessment_bindings, &{&1.intervention_id, &1})

    points =
      Enum.map(authoring_view.decision_points, fn point ->
        candidate = Map.get(candidate_by_resource, point.alternatives_resource_id)
        options = candidate_options(candidate)

        mappings =
          point
          |> then(&Map.get(mappings_by_point, &1.id, []))
          |> Enum.map(fn mapping ->
            condition = Enum.find(conditions, &(&1.id == mapping.condition_id))

            %{
              condition_id: mapping.condition_id,
              condition_label: condition.label || condition.condition_code,
              option_id: mapping.option_id,
              weight: mapping.weight,
              options: options
            }
          end)

        interventions =
          point
          |> then(&Map.get(interventions_by_point, &1.id, []))
          |> Enum.map(fn intervention ->
            binding = Map.get(bindings_by_intervention, intervention.id)

            %{
              page_resource_id: intervention.page_resource_id,
              content_element_id: intervention.content_element_id,
              assessment_page_resource_id: binding && binding.assessment_page_resource_id,
              reward_threshold: binding && binding.reward_threshold
            }
          end)

        %{
          alternatives_resource_id: point.alternatives_resource_id,
          decision_point_key: point.decision_point_key,
          title: point.title || (candidate && candidate.title),
          algorithm: point.algorithm,
          mappings: mappings,
          interventions: interventions,
          prior_alpha: point.prior_alpha,
          prior_beta: point.prior_beta,
          warm_up_assignments: point.warm_up_assignments,
          max_condition_share: point.max_condition_share,
          fixed_control_allocation: point.fixed_control_allocation,
          imbalance_threshold: point.imbalance_threshold
        }
      end)

    %{conditions: conditions, decision_points: points}
  end

  defp draft_point(candidate, conditions) do
    options = candidate_options(candidate)

    mappings =
      conditions
      |> Enum.with_index()
      |> Enum.map(fn {condition, index} ->
        {_label, option_id} = Enum.at(options, index) || List.first(options) || {"", ""}

        %{
          condition_id: condition.id,
          condition_label: condition.label || condition.condition_code,
          option_id: option_id,
          weight: 1.0,
          options: options
        }
      end)

    %{
      alternatives_resource_id: candidate.alternatives_resource_id,
      decision_point_key: candidate.decision_point_key,
      title: candidate.title,
      algorithm: :weighted_random,
      mappings: mappings,
      interventions: [empty_intervention()],
      prior_alpha: 1.0,
      prior_beta: 1.0,
      warm_up_assignments: 0,
      max_condition_share: 1.0,
      fixed_control_allocation: nil,
      imbalance_threshold: 1.0
    }
  end

  defp candidate_options(nil), do: []

  defp candidate_options(candidate),
    do: Enum.map(candidate.options, &{candidate.option_labels[&1] || &1, &1})

  defp empty_intervention do
    %{
      page_resource_id: nil,
      content_element_id: nil,
      assessment_page_resource_id: nil,
      reward_threshold: "1.0"
    }
  end

  defp unused_candidates(graph_draft, candidates) do
    used = MapSet.new(graph_draft.decision_points, & &1.alternatives_resource_id)
    Enum.reject(candidates, &MapSet.member?(used, &1.alternatives_resource_id))
  end

  defp build_picker(socket, "intervention_page", point_index, intervention_index) do
    with {:ok, options} <- ABExperiments.list_available_pages(authoring_scope(socket)) do
      {:ok,
       %{
         title: "Choose intervention page",
         label: "Unscored page",
         options: options,
         filter: fn option -> not option.graded end,
         description_key: nil,
         position_key: nil,
         selection_mode: :single,
         selected_values: [],
         page: 1,
         page_size: 8,
         point_index: point_index,
         intervention_index: intervention_index,
         key: :page_resource_id
       }}
    end
  end

  defp build_picker(socket, "assessment_page", point_index, intervention_index) do
    with {:ok, options} <- ABExperiments.list_available_pages(authoring_scope(socket)) do
      {:ok,
       %{
         title: "Choose scored page",
         label: "Scored page",
         options: options,
         filter: fn option -> option.graded end,
         description_key: nil,
         position_key: nil,
         selection_mode: :single,
         selected_values: [],
         page: 1,
         page_size: 8,
         point_index: point_index,
         intervention_index: intervention_index,
         key: :assessment_page_resource_id
       }}
    end
  end

  defp build_picker(socket, "placement_element", point_index, intervention_index) do
    with %{page_resource_id: page_resource_id} <-
           get_in(socket.assigns.graph_draft, [
             :decision_points,
             Access.at(point_index),
             :interventions,
             Access.at(intervention_index)
           ]),
         true <- is_integer(page_resource_id),
         {:ok, options} <-
           ABExperiments.list_page_alternatives_elements(
             page_resource_id,
             authoring_scope(socket)
           ) do
      {:ok,
       %{
         title: "Choose placement element",
         label: "A/B Test Alternatives",
         description: "Elements are listed in the order they appear on the page",
         options: Enum.map(options, &describe_element_option/1),
         filter: &experiment_alternatives_element?/1,
         description_key: :description,
         position_key: :position,
         selection_mode: :single,
         selected_values: [],
         page: 1,
         page_size: 8,
         point_index: point_index,
         intervention_index: intervention_index,
         key: :content_element_id
       }}
    end
  end

  defp build_picker(_socket, _kind, _point_index, _intervention_index),
    do: {:error, :invalid_picker}

  defp experiment_alternatives_element?(option),
    do: option.type == "alternatives" and option.experiment_controlled?

  defp describe_element_option(option) do
    option
    |> Map.put(:label, element_type_label(option.type))
    |> Map.put(
      :description,
      OliWeb.Common.Utils.extract_text_from_content(option.content)
    )
  end

  defp element_type_label("alternatives"), do: "Alternative Content"
  defp element_type_label(type), do: Oli.Utils.snake_case_to_friendly(type)

  defp parse_picker_value(:content_element_id, value) when is_binary(value) and value != "",
    do: {:ok, value}

  defp parse_picker_value(key, value)
       when key in [:page_resource_id, :assessment_page_resource_id],
       do: parse_positive_integer(value)

  defp parse_picker_value(_key, _value), do: {:error, :invalid_picker_value}

  defp toggle_picker_value(values, value) do
    case value in values do
      true -> List.delete(values, value)
      false -> [value | values]
    end
  end

  defp maybe_clear_element_selection(intervention, :page_resource_id),
    do: %{intervention | content_element_id: nil}

  defp maybe_clear_element_selection(intervention, _key), do: intervention

  defp page_option_label(options, resource_id) do
    case Enum.find(options, &(&1.value == resource_id)) do
      nil -> if(resource_id, do: "Selected page", else: nil)
      option -> option.label
    end
  end

  defp decision_point_candidates(%{definition: %{state: :draft}}, scope),
    do: ABExperiments.list_available_decision_points(scope)

  defp decision_point_candidates(authoring_view, _scope) do
    {:ok,
     Enum.map(authoring_view.decision_points, fn point ->
       %Oli.Experiments.DecisionPointCandidate{
         alternatives_resource_id: point.alternatives_resource_id,
         decision_point_key: point.decision_point_key,
         title: point.title
       }
     end)}
  end

  defp update_draft_list(socket, field, _index, fun) do
    case socket.assigns.experiment.state do
      :draft ->
        {:noreply, update(socket, :graph_draft, &Map.update!(&1, field, fun))}

      _ ->
        {:noreply, assign(socket, configuration_error: "Experiment configuration is read-only.")}
    end
  end

  defp update_graph_points(socket, fun) do
    case socket.assigns.experiment.state do
      :draft ->
        {:noreply, update(socket, :graph_draft, &Map.update!(&1, :decision_points, fun))}

      _ ->
        {:noreply, assign(socket, configuration_error: "Experiment configuration is read-only.")}
    end
  end

  defp parse_index(value) when is_integer(value) and value >= 0, do: {:ok, value}

  defp parse_index(value) when is_binary(value) do
    case Integer.parse(value) do
      {index, ""} when index >= 0 -> {:ok, index}
      _ -> {:error, :invalid_index}
    end
  end

  defp parse_index(_value), do: {:error, :invalid_index}

  defp invalid_configuration_event(socket),
    do: {:noreply, assign(socket, configuration_error: "Invalid configuration selection.")}

  defp configuration_request(socket, params) do
    with {:ok, conditions} <- parse_conditions(params["conditions"]),
         {:ok, decision_points} <- parse_decision_points(params["decision_points"], conditions) do
      {:ok,
       %UpdateExperimentRequest{
         scope: authoring_scope(socket),
         conditions: conditions,
         decision_points: decision_points
       }}
    end
  end

  defp parse_conditions(params) when is_map(params) do
    params
    |> ordered_values()
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {condition, position}, {:ok, acc} ->
      with {:ok, id} <- parse_positive_integer(condition["id"]),
           label when is_binary(label) and label != "" <- String.trim(condition["label"] || ""),
           {:ok, active} <- parse_boolean(condition["active"]) do
        {:cont, {:ok, [%{id: id, label: label, active: active, position: position} | acc]}}
      else
        _ -> {:halt, {:error, "Every condition requires a label and valid identity."}}
      end
    end)
    |> reverse_parsed_values()
  end

  defp parse_conditions(_params), do: {:error, "At least two conditions are required."}

  defp parse_decision_points(params, conditions) when is_map(params) do
    params
    |> ordered_values()
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {point, position}, {:ok, acc} ->
      case parse_decision_point(point, conditions, position) do
        {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
        error -> {:halt, error}
      end
    end)
    |> reverse_parsed_values()
  end

  defp parse_decision_points(_params, _conditions),
    do: {:error, "At least one decision point is required."}

  defp parse_decision_point(point, conditions, position) do
    with {:ok, resource_id} <- parse_positive_integer(point["alternatives_resource_id"]),
         {:ok, algorithm} <- parse_algorithm(point["algorithm"]),
         {:ok, mappings} <- parse_mappings(point["mappings"], conditions),
         {:ok, interventions} <- parse_interventions(point["interventions"], algorithm),
         {:ok, policy_fields} <- parse_policy_fields(point, algorithm) do
      {:ok,
       %{
         alternatives_resource_id: resource_id,
         decision_point_key: point["decision_point_key"],
         title: point["title"] || "Decision point #{position + 1}",
         algorithm: algorithm,
         prior_alpha: policy_fields.prior_alpha,
         prior_beta: policy_fields.prior_beta,
         warm_up_assignments: policy_fields.warm_up_assignments,
         max_condition_share: policy_fields.max_condition_share,
         fixed_control_allocation: policy_fields.fixed_control_allocation,
         imbalance_threshold: policy_fields.imbalance_threshold,
         reward_source: policy_fields.reward_source,
         mappings: mappings,
         interventions: interventions,
         position: position
       }}
    else
      _ -> {:error, "Decision-point configuration contains an invalid value."}
    end
  end

  defp parse_mappings(params, conditions) when is_map(params) do
    valid_condition_ids = MapSet.new(conditions, & &1.id)

    params
    |> ordered_values()
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {mapping, position}, {:ok, acc} ->
      with {:ok, condition_id} <- parse_positive_integer(mapping["condition_id"]),
           true <- MapSet.member?(valid_condition_ids, condition_id),
           option_id when is_binary(option_id) and option_id != "" <- mapping["option_id"],
           {:ok, weight} <- parse_non_negative_number(mapping["weight"]) do
        {:cont,
         {:ok,
          [
            %{
              condition_id: condition_id,
              option_id: option_id,
              weight: weight,
              position: position
            }
            | acc
          ]}}
      else
        _ ->
          {:halt, {:error, "Each mapping requires a condition, option, and non-negative weight."}}
      end
    end)
    |> reverse_parsed_values()
  end

  defp parse_mappings(_params, _conditions), do: {:error, "Every condition must be mapped."}

  defp parse_interventions(params, algorithm) when is_map(params) do
    params
    |> ordered_values()
    |> Enum.reduce_while({:ok, []}, fn intervention, {:ok, acc} ->
      with {:ok, page_resource_id} <- parse_positive_integer(intervention["page_resource_id"]),
           element_id when is_binary(element_id) and element_id != "" <-
             String.trim(intervention["content_element_id"] || ""),
           {:ok, binding} <- parse_binding(intervention, algorithm) do
        parsed = %{
          page_resource_id: page_resource_id,
          content_element_id: element_id,
          assessment_binding: binding
        }

        {:cont, {:ok, [parsed | acc]}}
      else
        _ -> {:halt, {:error, "Every intervention requires a page resource and placement ID."}}
      end
    end)
    |> reverse_parsed_values()
  end

  defp parse_interventions(_params, _algorithm),
    do: {:error, "Each decision point requires an intervention."}

  defp reverse_parsed_values({:ok, values}), do: {:ok, Enum.reverse(values)}
  defp reverse_parsed_values(error), do: error

  defp parse_binding(_params, :weighted_random), do: {:ok, nil}

  defp parse_binding(params, :thompson_sampling) do
    with {:ok, page_id} <- parse_positive_integer(params["assessment_page_resource_id"]),
         {:ok, threshold} <- parse_share(params["reward_threshold"]) do
      {:ok,
       %{assessment_page_resource_id: page_id, reward_threshold: Decimal.from_float(threshold)}}
    end
  end

  defp parse_policy_fields(point, algorithm)
       when algorithm in [:weighted_random, :thompson_sampling] do
    with {:ok, alpha} <- parse_positive_number(point["prior_alpha"]),
         {:ok, beta} <- parse_positive_number(point["prior_beta"]),
         {:ok, warm_up} <- parse_non_negative_integer(point["warm_up_assignments"]),
         {:ok, max_share} <- parse_share(point["max_condition_share"]),
         {:ok, fixed} <- parse_optional_share(point["fixed_control_allocation"]),
         {:ok, imbalance} <- parse_share(point["imbalance_threshold"]) do
      {:ok,
       %{
         prior_alpha: alpha,
         prior_beta: beta,
         warm_up_assignments: warm_up,
         max_condition_share: max_share,
         fixed_control_allocation: fixed,
         imbalance_threshold: imbalance,
         reward_source: "assessment_page:normalized_score"
       }}
    end
  end

  defp submitted_point_changes(params) when is_map(params) do
    Enum.reduce(params, %{}, fn {index, point}, changes ->
      with {:ok, parsed_index} <- parse_index(index),
           {:ok, algorithm} <- parse_algorithm(point["algorithm"]) do
        policy_changes =
          ~w(prior_alpha prior_beta warm_up_assignments max_condition_share fixed_control_allocation imbalance_threshold)
          |> Enum.reduce(%{algorithm: algorithm}, fn key, point_changes ->
            case Map.fetch(point, key) do
              {:ok, value} -> Map.put(point_changes, String.to_existing_atom(key), value)
              :error -> point_changes
            end
          end)

        point_changes =
          policy_changes
          |> Map.put(:mappings, submitted_mapping_changes(point["mappings"]))
          |> Map.put(:interventions, submitted_intervention_changes(point["interventions"]))

        Map.put(changes, parsed_index, point_changes)
      else
        _ -> changes
      end
    end)
  end

  defp submitted_point_changes(_params), do: %{}

  defp submitted_condition_changes(params) when is_map(params) do
    submitted_indexed_changes(params, fn condition ->
      %{}
      |> put_submitted(:label, condition["label"])
      |> put_submitted(:active, submitted_boolean(condition["active"]))
    end)
  end

  defp submitted_condition_changes(_params), do: %{}

  defp submitted_mapping_changes(params) when is_map(params) do
    submitted_indexed_changes(params, fn mapping ->
      %{}
      |> put_submitted(:option_id, mapping["option_id"])
      |> put_submitted(:weight, mapping["weight"])
    end)
  end

  defp submitted_mapping_changes(_params), do: %{}

  defp submitted_intervention_changes(params) when is_map(params) do
    submitted_indexed_changes(params, fn intervention ->
      %{}
      |> put_submitted(
        :page_resource_id,
        submitted_positive_integer(intervention["page_resource_id"])
      )
      |> put_submitted(:content_element_id, intervention["content_element_id"])
      |> put_submitted(
        :assessment_page_resource_id,
        submitted_positive_integer(intervention["assessment_page_resource_id"])
      )
      |> put_submitted(:reward_threshold, intervention["reward_threshold"])
    end)
  end

  defp submitted_intervention_changes(_params), do: %{}

  defp submitted_indexed_changes(params, changes_for_value) do
    Enum.reduce(params, %{}, fn {index, value}, changes ->
      case parse_index(index) do
        {:ok, parsed_index} -> Map.put(changes, parsed_index, changes_for_value.(value))
        _ -> changes
      end
    end)
  end

  defp merge_indexed_changes(values, changes) do
    Enum.with_index(values, fn value, index ->
      case Map.get(changes, index) do
        %{mappings: mapping_changes, interventions: intervention_changes} = value_changes ->
          value
          |> Map.merge(Map.drop(value_changes, [:mappings, :interventions]))
          |> Map.update!(:mappings, &merge_indexed_changes(&1, mapping_changes))
          |> Map.update!(:interventions, &merge_indexed_changes(&1, intervention_changes))

        value_changes when is_map(value_changes) ->
          Map.merge(value, value_changes)

        nil ->
          value
      end
    end)
  end

  defp put_submitted(changes, _key, nil), do: changes
  defp put_submitted(changes, key, value), do: Map.put(changes, key, value)

  defp submitted_boolean("true"), do: true
  defp submitted_boolean("false"), do: false
  defp submitted_boolean(value), do: value

  defp submitted_positive_integer(value) do
    case parse_positive_integer(value) do
      {:ok, parsed} -> parsed
      _ -> value
    end
  end

  defp ordered_values(map) do
    map
    |> Enum.reduce_while({:ok, []}, fn {key, value}, {:ok, acc} ->
      case parse_index(key) do
        {:ok, index} -> {:cont, {:ok, [{index, value} | acc]}}
        _ -> {:halt, {:error, :invalid_collection}}
      end
    end)
    |> case do
      {:ok, indexed} -> indexed |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1))
      {:error, _} -> []
    end
  end

  defp parse_algorithm("weighted_random"), do: {:ok, :weighted_random}
  defp parse_algorithm("thompson_sampling"), do: {:ok, :thompson_sampling}
  defp parse_algorithm(_), do: {:error, :invalid_algorithm}

  defp parse_boolean("true"), do: {:ok, true}
  defp parse_boolean("false"), do: {:ok, false}
  defp parse_boolean(_), do: {:error, :invalid_boolean}

  defp parse_non_negative_number(value) do
    case Float.parse(value || "") do
      {number, ""} when number >= 0 -> {:ok, number}
      _ -> {:error, :invalid_number}
    end
  end

  defp parse_positive_number(value) do
    case parse_non_negative_number(value) do
      {:ok, number} when number >= 0.0001 and number <= 1000 -> {:ok, number}
      _ -> {:error, :invalid_number}
    end
  end

  defp parse_non_negative_integer(value) do
    case Integer.parse(value || "") do
      {number, ""} when number >= 0 -> {:ok, number}
      _ -> {:error, :invalid_integer}
    end
  end

  defp parse_share(value) do
    case parse_non_negative_number(value) do
      {:ok, number} when number >= 0 and number <= 1 -> {:ok, number}
      _ -> {:error, :invalid_share}
    end
  end

  defp parse_optional_share(value) when value in [nil, ""], do: {:ok, nil}
  defp parse_optional_share(value), do: parse_share(value)

  defp condition_rows(authoring_view) do
    conditions = Map.new(authoring_view.conditions, &{&1.id, &1})

    Enum.map(authoring_view.mappings, fn mapping ->
      %{mapping: mapping, condition: Map.fetch!(conditions, mapping.condition_id)}
    end)
  end

  defp show_policy_report?(experiment, snapshot),
    do: experiment.state != :draft and snapshot != []

  defp format_percent(value), do: :erlang.float_to_binary(value * 100, decimals: 1) <> "%"

  defp format_policy_mode(:warm_up_weighted_random), do: "Warm-up weighted random"
  defp format_policy_mode(:fixed_control), do: "Fixed-control enforcement"
  defp format_policy_mode(:traffic_cap), do: "Traffic-cap enforcement"
  defp format_policy_mode(:thompson_sampling), do: "Thompson Sampling"

  defp policy_mode_help(:warm_up_weighted_random),
    do:
      "Assignments are being distributed for initial evidence before adaptive allocation begins."

  defp policy_mode_help(:fixed_control),
    do:
      "Allocation is currently preserving the configured assignment share for the control condition."

  defp policy_mode_help(:traffic_cap),
    do:
      "The traffic cap is preventing a condition from exceeding its configured maximum assignment share."

  defp policy_mode_help(:thompson_sampling),
    do:
      "No guardrail is currently active; Thompson Sampling is using the current posterior evidence."

  defp policy_mode_help(_mode), do: "The allocation behavior currently active for this condition."

  defp guardrail_progress(%{effective_mode: :warm_up_weighted_random} = row) do
    "Warm-up progress: #{row.guardrail_state["assignment_count"]}/#{row.guardrail_state["warm_up_assignments"]} assignments"
  end

  defp guardrail_progress(%{effective_mode: :fixed_control} = row) do
    "Fixed-control target: #{format_percent(row.guardrail_state["fixed_control_allocation"])}"
  end

  defp guardrail_progress(%{effective_mode: :traffic_cap} = row) do
    "Traffic cap: #{format_percent(row.guardrail_state["max_condition_share"])}"
  end

  defp guardrail_progress(row) do
    "Imbalance warning threshold: #{format_percent(row.guardrail_state["imbalance_threshold"])}"
  end

  defp lifecycle_policy_message(:paused),
    do: "Assignment is paused. The policy snapshot remains current."

  defp lifecycle_policy_message(:completed),
    do: "Assignment has ended. This is the frozen final snapshot."

  defp lifecycle_policy_message(:archived),
    do: "This archived experiment shows its frozen final snapshot."

  defp format_snapshot_datetime(nil), do: "—"
  defp format_snapshot_datetime(value), do: Calendar.strftime(value, "%Y-%m-%d %H:%M UTC")

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

  defp status_badge_class(:active), do: "badge-primary"
  defp status_badge_class(:completed), do: "badge-success"
  defp status_badge_class(_state), do: "badge-secondary"

  defp parse_confirmation_action("complete"), do: {:ok, :complete}
  defp parse_confirmation_action("archive"), do: {:ok, :archive}
  defp parse_confirmation_action(_action), do: {:error, :invalid_action}

  defp transition_available?(state, :complete), do: state in [:active, :paused]
  defp transition_available?(:completed, :archive), do: true
  defp transition_available?(_state, _action), do: false

  defp transition_title(:complete), do: "Complete Experiment"
  defp transition_title(:archive), do: "Archive Experiment"

  defp transition_button_label(:complete), do: "Complete"
  defp transition_button_label(:archive), do: "Archive"

  defp transition_confirmation(experiment, :complete) do
    "Complete “#{experiment.name}”? Participation can no longer be changed after completion."
  end

  defp transition_confirmation(experiment, :archive) do
    "Archive “#{experiment.name}”? The experiment will be removed from active use."
  end

  defp decision_point_algorithms(decision_points) do
    decision_points
    |> Enum.map(&format_algorithm(&1.algorithm))
    |> Enum.uniq()
    |> Enum.join(", ")
    |> case do
      "" -> "—"
      algorithms -> algorithms
    end
  end

  defp display_value(nil), do: "—"

  defp display_value(value),
    do: value |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp format_date(nil), do: "—"
  defp format_date(%DateTime{} = value), do: value |> DateTime.to_date() |> format_date()

  defp format_date(%NaiveDateTime{} = value),
    do: value |> NaiveDateTime.to_date() |> format_date()

  defp format_date(%Date{} = value), do: Oli.Cldr.Date.to_string!(value, format: :medium)
end
